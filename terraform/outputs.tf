output "frontend_url" {
  description = "URL do frontend"
  value       = "https://${var.nome_aluno}.lab.tonanuvem.com"
}

output "api_url" {
  description = "URL da API"
  value       = "https://api.${var.nome_aluno}.lab.tonanuvem.com"
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda.function_name
}

output "zone_id" {
  description = "ID da zona hospedada no Route 53"
  value       = var.id_zona_hospedada
}
