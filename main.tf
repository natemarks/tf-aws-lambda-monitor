provider "aws" {
  region = "us-east-1"
}


# -----------------------------------------------------------------------------
# Create thr role for the lambda
# -----------------------------------------------------------------------------

resource "aws_iam_role" "this" {
  name = var.function_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


# -----------------------------------------------------------------------------
# Attach AWS -managed policies to the  function iam role
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaReadOnlyAccess" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "AWSXrayWriteOnlyAccess" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}


# -----------------------------------------------------------------------------
# Create the lambda function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role = aws_iam_role.this.arn
  handler = var.handler_name
  memory_size = var.memory_size
  s3_bucket = var.source_bucket
  s3_key = var.source_key
  #s3_object_version = var.source_object_version
  source_code_hash = filebase64sha256("${var.handler_name}.zip")

  runtime = var.function_runtime
  tracing_config {
    mode = var.tracing_mode
  }

  tags = merge(
  {
    terraform = "true"
    terragrunt = "true"
  },
  var.custom_tags,
  )

  environment {
    variables = merge(
    {
      DEBUG = "FALSE"
      RANDOM_FAILURES = "FALSE"
    },
    var.environment_variables,
    )
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.this,
  ]
}


# -----------------------------------------------------------------------------
# Manage the log retention
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.lambda_log_retention_in_days
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# -----------------------------------------------------------------------------
# Create the event to fire the lambda
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "this" {
  name_prefix         = var.function_name
  description         = var.schedule_expression_desc
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "lambda"
  arn       = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}


# -----------------------------------------------------------------------------
# Create the SNS topic to opsgenie
# https://docs.opsgenie.com/docs/aws-cloudwatch-integration
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "this" {
  name = "opsgenie"
}

resource "aws_sns_topic_subscription" "this" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "https"
  endpoint  = var.opsgenie_https_sns_endpoint
}


# -----------------------------------------------------------------------------
# Create the alarm and the metric log filter to trigger when we get the p1
# event that the dns monitor generates when there are too few IP addresses in
# the dns response
# -----------------------------------------------------------------------------


resource "aws_cloudwatch_metric_alarm" "too_few_addresses" {
  alarm_name                = "OpsGenie: lambda-dns-lookup-monitor (too few addresses)"
  alarm_description         = "When lambda-dns-lookup-monitor throws sev 1: too few addresses, alert OpsGenie"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "transform too_few_addresses events"
  namespace                 = var.function_name
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "0"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.this.arn]
  ok_actions          = [aws_sns_topic.this.arn]
  insufficient_data_actions = []
}

resource "aws_cloudwatch_log_metric_filter" "too_few_addresses" {
  name           = "Count of too-few-addresses events"
  pattern        = "{$.imprivata_event_severity = 1}"
  log_group_name = "/aws/lambda/${var.function_name}"

  metric_transformation {
    name      = "transform too_few_addresses events"
    namespace = var.function_name
    value     = "1"
    default_value = "0"
  }
  depends_on = [
    aws_cloudwatch_log_group.this,
  ]
}
