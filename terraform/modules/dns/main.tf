# Registro DNS para a API
resource "aws_route53_record" "api" {
  zone_id = var.zone_id
  name    = "api.${var.nome_aluno}.lab.tonanuvem.com"
  type    = "A"

  alias {
    name                   = var.api_gateway_domain
    zone_id                = var.api_gateway_domain_zone_id
    evaluate_target_health = false
  }
}

# Registro DNS para o frontend
resource "aws_route53_record" "frontend" {
  zone_id = var.zone_id
  name    = "${var.nome_aluno}.lab.tonanuvem.com"
  type    = "A"

  alias {
    name                   = var.frontend_domain
    zone_id                = var.frontend_domain_zone_id
    evaluate_target_health = false
  }
} 