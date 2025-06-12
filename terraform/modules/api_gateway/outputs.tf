output "api_id" {
  description = "ID da API Gateway"
  value       = aws_apigatewayv2_api.api.id
}

output "api_endpoint" {
  description = "Endpoint da API Gateway"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "domain_name" {
  description = "Nome de domínio da API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name
}

output "domain_name_configuration" {
  description = "Configuração do domínio da API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration
} 