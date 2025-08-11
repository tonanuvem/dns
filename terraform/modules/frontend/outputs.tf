output "frontend_bucket_name" {
  description = "Nome do bucket S3 do frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN do bucket S3 do frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_domain_name" {
  description = "Nome de domínio do frontend"
  # O nome de domínio completo que será usado para acessar o site (via CNAME)
  value       = "www.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"
}

output "frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  value       = var.frontend_id_zona_hospedada
}

output "frontend_url" {
  description = "URL do frontend (via CNAME)"
  value       = "http://www.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"
}

output "frontend_website_endpoint" {
  description = "Endpoint do S3 website do frontend"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
