output "frontend_bucket_name" {
  description = "Nome do bucket S3 do frontend (exposto pelo root module para uso em scripts)"
  value       = module.frontend.frontend_bucket_name
}

# ============================================================
# URLs do ambiente
#
# O config.sh anunciava "https://www.<turma>.<dominio>", um host que
# nunca existiu: o bucket carrega um sufixo sorteado e o S3 website
# so atende HTTP. Os outputs abaixo sao a fonte da verdade -- o
# deploy.sh passa a imprimir exatamente o que foi criado.
# ============================================================

output "frontend_url" {
  description = "Site do gerenciador (S3 website, somente HTTP)"
  value       = module.frontend.frontend_url
}

output "frontend_url_https" {
  description = "Mesmo site com TLS, servido pelo proxy do API Gateway"
  value       = "https://https.${var.nome_aluno}.${var.nome_dominio}"
}

output "api_url" {
  description = "API no domínio personalizado"
  value       = "https://api.${var.nome_aluno}.${var.nome_dominio}"
}

output "api_invoke_url" {
  description = "URL de invoke do API Gateway (atalho para diagnóstico)"
  value       = module.api_gateway.api_invoke_url
}

output "zona_dns" {
  description = "Zona hospedada onde os alunos criam os aliases"
  value       = "${var.nome_aluno}.${var.nome_dominio} (${var.id_zona_hospedada})"
}

output "senha_admin" {
  description = "Senha de instrutor. Leia com: terraform output -raw senha_admin"
  value       = local.senha_admin
  sensitive   = true
}
