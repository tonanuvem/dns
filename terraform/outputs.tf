output "api_endpoint" {
  description = "Endpoint da API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "frontend_url" {
  description = "URL do frontend"
  value       = module.frontend.frontend_url
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = module.lambda_api.dynamodb_table_name
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda.function_name
}

output "zone_id" {
  description = "ID da zona hospedada no Route 53"
  value       = var.id_zona_hospedada
}
