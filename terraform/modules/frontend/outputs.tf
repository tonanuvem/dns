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
  # Usa o dominio realmente criado. Antes era "www.<turma>.<dominio>",
  # um host que nunca existiu: o bucket carrega o sufixo sorteado
  # (wwwNN), e era daqui que vinha a URL errada no fim do config.sh.
  value       = local.frontend_domain
}

output "frontend_sufixo" {
  description = "Sufixo numérico sorteado, usado para emparelhar os hostnames do frontend"
  # O proxy HTTPS deriva o hostname dele deste mesmo numero. Com um
  # valor fixo (era "www2"), um sorteio de 2 faria o Route 53 receber
  # um CNAME e um A-alias com o mesmo nome, e o apply quebraria.
  value       = random_integer.frontend.result
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
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
