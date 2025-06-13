output "api_gateway_id" {
  description = "ID da API Gateway"
  value       = aws_apigatewayv2_api.api.id
}

output "api_gateway_endpoint" {
  description = "Endpoint da API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "api_gateway_domain_name" {
  description = "Nome de domínio personalizado da API"
  value       = aws_apigatewayv2_domain_name.api.domain_name
}

output "api_gateway_domain_configuration" {
  description = "Configuração do domínio personalizado"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration
} 