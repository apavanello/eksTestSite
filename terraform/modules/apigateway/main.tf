resource "aws_lambda_function" "proxy" {
  function_name = "${var.name_prefix}-api-proxy"
  role          = var.lambda_role_arn
  runtime       = "python3.12"
  handler       = "index.handler"
  publish       = false

  filename         = "${path.module}/lambda/proxy.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/proxy.zip")

  environment {
    variables = {
      ENVIRONMENT = var.environment
      REGION      = "us-east-1"
    }
  }

  tags = var.common_tags
}

resource "aws_lambda_permission" "apigateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.proxy.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"

  tags = var.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.proxy.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "hello" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_deployment" "this" {
  api_id = aws_apigatewayv2_api.this.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "this" {
  api_id        = aws_apigatewayv2_api.this.id
  name          = "v1"
  deployment_id = aws_apigatewayv2_deployment.this.id

  tags = var.common_tags
}
