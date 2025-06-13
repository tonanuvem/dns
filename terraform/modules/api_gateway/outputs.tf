output "api_gateway_id" {
  description = "ID da API Gateway"
  value       = aws_apigatewayv2_api.api.id
}

output "api_gateway_endpoint" {
  description = "Endpoint da API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "api_gateway_domain_name" {
  description = "Nome de domínio da API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name
}

output "api_gateway_domain_zone_id" {
  description = "ID da zona do domínio da API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
}

output "api_gateway_domain_configuration" {
  description = "Configuração do domínio da API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration
}

output "api_gateway_lambda_invoke_arn" {
  description = "ARN para invocar a função Lambda através da API Gateway"
  value       = aws_apigatewayv2_integration.lambda_integration.integration_uri
}