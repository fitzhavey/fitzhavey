// As per https://learn.hashicorp.com/tutorials/terraform/lambda-api-gateway

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

// Name the bucket and prefix for other AWS resources
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-fitzhavey-readme"
}


resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

// Generates a zip of the lambda function
data "archive_file" "lambda_random_gif" {
  type = "zip"

  source_dir  = "${path.module}/../random-gif"
  output_path = "${path.module}/random-gif.zip"
}

// Uploads the zip to our S3 bucket
resource "aws_s3_object" "lambda_random_gif" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "readme-lambda.zip"
  source = data.archive_file.lambda_random_gif.output_path

  etag = filemd5(data.archive_file.lambda_random_gif.output_path)
}

// Configures the lambda function to use the bucket object containing the function code
resource "aws_lambda_function" "random_gif" {
  function_name = "RandomGif"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_random_gif.key

  runtime = "nodejs12.x"
  handler = "index.handler"

  environment {
    variables = {
      // See aws_secretsmanager_secret_version block below for secrets configuration
      GIPHY_API_KEY = data.aws_secretsmanager_secret_version.giphy_api_key.secret_string
    }
  }

  // Changes whenever the output code changes
  source_code_hash = data.archive_file.lambda_random_gif.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

// Defines a log group to store log messages from the lambda function
resource "aws_cloudwatch_log_group" "random_gif" {
  name = "/aws/lambda/${aws_lambda_function.random_gif.function_name}"

  retention_in_days = 30
}

// Defines an IAM role that allows lambda to access resources on your AWS account
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }]
  })
}

// Attaches a policy to the IAM role created above, allowing us to write to cloudwatch logs
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// Defines a name for the API gateway and sets its protocol to HTTP
resource "aws_apigatewayv2_api" "lambda" {
  name          = "lambda_fitzhavey_readme"
  protocol_type = "HTTP"
}

// Sets up application stages for the API Gateway - such as "Test", "Staging", and "Production". The example configuration defines a single stage, with access logging enabled.
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "${aws_apigatewayv2_api.lambda.name}-production"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

// Configures the API Gateway to use your Lambda function.
resource "aws_apigatewayv2_integration" "random_gif" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.random_gif.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

// Maps an HTTP request to the lambda function
resource "aws_apigatewayv2_route" "random_gif" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /search"
  target    = "integrations/${aws_apigatewayv2_integration.random_gif.id}"
}

// Defines a log group to store access logs for the gateway stage
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

// Gives API Gateway permission to invoke the lambda function
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.random_gif.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

// Defines a secret and stores it in aws cloud
resource "aws_secretsmanager_secret" "giphy_api_key" {
  name = "giphy_api_key"
  tags = {
    project = "fitzhavey-readme"
  }
}

// Defines the value of the secret in the terraform state
data "aws_secretsmanager_secret_version" "giphy_api_key" {
  secret_id = aws_secretsmanager_secret.giphy_api_key.name
}