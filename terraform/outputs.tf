output "api_gateway_endpoint" {
  description = "Endpoint da API Gateway"
  value       = module.api_gateway.api_gateway_endpoint
}

output "frontend_url" {
  description = "URL do frontend"
  value       = module.frontend.frontend_url
}

output "frontend_domain_name" {
  description = "Nome de domínio do frontend"
  value       = module.frontend.frontend_domain_name
}

output "frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  value       = module.frontend.frontend_domain_zone_id
}

output "lambda_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = module.lambda_api.lambda_dynamodb_table_name
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda_api.lambda_function_name
}

output "api_gateway_domain_name" {
  description = "Nome de domínio da API Gateway"
  value       = module.api_gateway.api_gateway_domain_name
}

output "api_gateway_domain_zone_id" {
  description = "ID da zona do domínio da API Gateway"
  value       = module.api_gateway.api_gateway_domain_zone_id
}

output "dns_api_record_name" {
  description = "Nome do registro DNS da API"
  value       = module.dns.dns_api_record_name
}

output "dns_frontend_record_name" {
  description = "Nome do registro DNS do frontend"
  value       = module.dns.dns_frontend_record_name
}

output "dns_zone_id" {
  description = "ID da zona hospedada"
  value       = module.dns.dns_zone_id
}

#output "dns_nameservers" {
#  description = "Nameservers da zona hospedada"
#  value       = module.dns.nameservers
#}