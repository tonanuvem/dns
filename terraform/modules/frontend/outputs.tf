# O bucket e criado pelo AWS CLI (ver main.tf), entao os valores abaixo
# vem dos locals, nao de atributos de um recurso aws_s3_bucket.

output "frontend_bucket_name" {
  description = "Nome do bucket S3 do frontend"
  value       = local.frontend_domain
}

output "frontend_bucket_arn" {
  description = "ARN do bucket S3 do frontend"
  value       = local.bucket_arn
}

output "frontend_domain_name" {
  description = "Nome de domínio do frontend"
  # Usa o dominio realmente criado. Antes era "www.<turma>.<dominio>",
  # um host que nunca existiu: o bucket carrega o sufixo sorteado
  # (wwwNN), e era daqui que vinha a URL errada no fim do config.sh.
  value = local.frontend_domain
}

output "frontend_sufixo" {
  description = "Sufixo numérico sorteado que compõe o nome do bucket"
  # Existe porque nome de bucket S3 e global na AWS. Nao use este
  # valor para montar outros hostnames: ele so e conhecido em tempo de
  # apply, e um for_each chaveado por ele quebra o plan.
  value = random_integer.frontend.result
}

output "frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  value       = var.frontend_id_zona_hospedada
}

output "frontend_url" {
  description = "URL do frontend (via CNAME, apenas HTTP: o S3 website não faz TLS)"
  value       = "http://${local.frontend_domain}"
}

output "frontend_website_endpoint" {
  description = "Endpoint do S3 website do frontend"
  value       = local.website_endpoint
}
