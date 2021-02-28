

variable "aws_account_id" {
  description = "Deployment account id"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy to (e.g. us-east-1)"
  type        = string
}

variable "custom_tags" {
  description = "A map of key value pairs that represents custom tags to apply to taggable resources"
  type        = map(string)
  default     = {}
}

variable "function_name" {
  description = "The AWS function name"
  type        = string
}

variable "handler_name" {
  description = "https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#handler"
  type        = string
}

variable "memory_size" {
  description = "Lambda memory size"
  type = number
  default = 128
}

variable "function_runtime" {
  description = "https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html"
  type = string
  default = "go1.x"
}

variable "tracing_mode" {
  description = "https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#tracing_config"
  type = string
  default = "PassThrough"
}

variable "source_bucket" {
  description = "The AWS function name"
  type        = string
}

variable "source_key" {
  description = "The AWS function name"
  type        = string
}

#variable "source_object_version" {
#  description = "The AWS function name"
#  type        = string
#}

variable "environment_variables" {
  description = "Default environment variables as a map of key value pairs"
  type        = map(string)
  default     = {}
}

variable "schedule_expression" {
  description = "https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule#schedule_expression"
  type = string
  default = "rate(1 minute)"
}

variable "schedule_expression_desc" {
  description = "Describe the intended schedule"
  type = string
  default = "Every minute"
}

variable "opsgenie_https_sns_endpoint" {
  description = "https://docs.opsgenie.com/docs/aws-cloudwatch-integration"
  type = string
}

variable "lambda_log_retention_in_days" {
  description = "Number of days to retain the lambda log"
  type = number
  default = 14
}