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
  value       = aws_api_gateway_domain_name.api_gateway_domain.domain_name
}

output "api_gateway_domain_zone_id" {
  description = "ID da zona do domínio da API Gateway"
  value       = aws_api_gateway_domain_name.api_gateway_domain.cloudfront_domain_name
}

output "api_gateway_domain_configuration" {
  description = "Configuração do domínio da API Gateway"
  value       = aws_api_gateway_domain_name.api_gateway_domain.domain_name_configuration
}

output "api_gateway_lambda_invoke_arn" {
  description = "ARN para invocar a função Lambda através da API Gateway"
  value       = aws_api_gateway_integration.lambda.integration_uri
} 