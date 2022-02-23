terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.2.0"
    }
  }
  required_version = ">= 1.1.6"
}

provider "aws" {
  profile = "default"
  region  = var.region
}

######################################
#  lambda roles
######################################
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda-role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy" "ssm" {
  name = "${var.project_name}-lambda-ssm"
  role = aws_iam_role.lambda-role.name
  policy = jsonencode({
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:Describe*",
          "ssm:Get*",
          "ssm:List*"
        ],
        "Resource" : "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.lambda-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

######################################
#  cron job
######################################
resource "aws_cloudwatch_event_rule" "cron-job" {
  name                = "${var.project_name}-cron"
  schedule_expression = "cron(0 0 8 12 ? *)" # every 8 of december
}

resource "aws_cloudwatch_event_target" "cron-target" {
  rule      = aws_cloudwatch_event_rule.cron-job.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda.arn
}


resource "aws_lambda_permission" "allow-cron" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cron-job.arn
}


######################################
#  lambda source code
######################################
data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "src"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  function_name    = "${var.project_name}-lambda"
  role             = aws_iam_role.lambda-role.arn
  description      = "Readme lambda"
  handler          = "lambda.handler"
  runtime          = "nodejs14.x"
  timeout          = 60
  memory_size      = 256

  layers = [
    "arn:aws:lambda:${var.region}:553035198032:layer:git-lambda2:8"
  ]

  environment {
    variables = {
      "REGION" : var.region
      "PAT" : var.pat
    }
  }
}

resource "aws_cloudwatch_log_group" "log-group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 7
}
