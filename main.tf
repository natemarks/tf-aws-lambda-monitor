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
  s3_object_version = var.source_object_version
  source_code_hash = filebase64sha256("${var.handler_name}}.zip")

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
      DEBUG_FUNCTION = "FALSE"
    },
    var.environment_variables,
    )
  }
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
