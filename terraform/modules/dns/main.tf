# Registro DNS para a API
resource "aws_route53_record" "api" {
  zone_id = var.dns_zone_id
  name    = "api.${var.dns_nome_aluno}.lab.tonanuvem.com"
  type    = "A"
  ttl     = 60

  alias {
    name                   = var.dns_api_gateway_domain
    zone_id                = var.dns_api_gateway_domain_zone_id
    evaluate_target_health = false
  }
}

# Registro DNS para o frontend
resource "aws_route53_record" "frontend" {
  zone_id = var.dns_zone_id
  name    = "${var.dns_nome_aluno}.lab.tonanuvem.com"
  type    = "A"
  ttl     = 60

  alias {
    name                   = var.dns_frontend_domain
    zone_id                = var.dns_frontend_domain_zone_id
    evaluate_target_health = false
  }
}