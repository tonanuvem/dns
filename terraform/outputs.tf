output "api_gateway_endpoint" {
  description = "Endpoint da API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "frontend_url" {
  description = "URL do frontend"
  value       = module.frontend.frontend_url
}

output "lambda_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = module.lambda_api.dynamodb_table_name
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda_api.function_name
}

output "dns_zone_id" {
  description = "ID da zona hospedada no Route 53"
  value       = var.id_zona_hospedada
}

output "dns_nameservers" {
  description = "Nameservers da zona hospedada"
  value       = module.dns.nameservers
}

output "dns_api_record" {
  description = "Nome do registro DNS da API"
  value       = module.dns.api_record_name
}

output "dns_frontend_record" {
  description = "Nome do registro DNS do frontend"
  value       = module.dns.frontend_record_name
}
 