# Registro DNS para a API
resource "aws_route53_record" "api" {
  count   = var.dns_api_gateway_domain != "" && var.dns_api_gateway_domain_zone_id != "" ? 1 : 0
  zone_id = var.dns_zone_id
  name    = "api.${var.dns_nome_aluno}"
  type    = "A"

  alias {
    name                   = var.dns_api_gateway_domain
    zone_id                = var.dns_api_gateway_domain_zone_id
    evaluate_target_health = false
  }
}

# Registro DNS para o frontend
resource "aws_route53_record" "frontend" {
  zone_id = var.dns_zone_id
  name    = "frontend.${var.dns_nome_aluno}"
  type    = "CNAME"
  ttl     = 60
  records = [var.dns_frontend_website_endpoint]
}