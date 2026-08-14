output "rest_api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "rest_api_arn" {
  value = aws_apigatewayv2_api.this.arn
}

output "invoke_url" {
  value = "${aws_apigatewayv2_api.this.api_endpoint}/v1/hello"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "api_hostname" {
  value = "${aws_apigatewayv2_api.this.id}.execute-api.localhost"
}

output "lambda_function_name" {
  value = aws_lambda_function.proxy.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.proxy.arn
}
