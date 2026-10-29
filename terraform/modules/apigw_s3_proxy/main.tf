provider "aws" {
  alias  = "regional"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.regional
  domain_name       = var.proxy_domain
  validation_method = "DNS"

  # O curinga da zona entra como SAN no mesmo certificado -- um segundo
  # certificado so para ele seria desperdicio, e a ACM valida os dois
  # nomes no mesmo pedido.
  subject_alternative_names = [var.proxy_wildcard_domain]

  # Trocar os nomes recria o certificado, e o dominio personalizado que
  # o referencia precisa nascer antes do antigo morrer.
  lifecycle {
    create_before_destroy = true
  }

  tags = var.proxy_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.proxy_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.regional
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_api_gateway_rest_api" "s3_proxy" {
  name        = "S3ProxyAPI"
  description = "API Gateway to proxy HTTPS requests to S3 static website"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.s3_proxy.id
  parent_id   = aws_api_gateway_rest_api.s3_proxy.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any_method" {
  rest_api_id   = aws_api_gateway_rest_api.s3_proxy.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "s3_integration" {
  rest_api_id             = aws_api_gateway_rest_api.s3_proxy.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.any_method.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.proxy_bucket_name}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ============================================================
# RAIZ "/"
#
# O recurso {proxy+} casa /index.html e /assets/..., mas NAO casa a
# raiz. Sem um metodo no recurso raiz, nenhuma rota casava com "/" e o
# API Gateway respondia 403 "Missing Authentication Token" -- o jeito
# dele de dizer que nao encontrou rota. Na pratica a URL HTTPS nao
# abria: so funcionava digitando /index.html.
#
# Nao leva request_parameters nem {proxy} na uri: aqui nao existe
# segmento de caminho para repassar, e o proprio S3 devolve o
# index.html configurado como documento de indice.
# ============================================================

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.s3_proxy.id
  resource_id   = aws_api_gateway_rest_api.s3_proxy.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root" {
  rest_api_id             = aws_api_gateway_rest_api.s3_proxy.id
  resource_id             = aws_api_gateway_rest_api.s3_proxy.root_resource_id
  http_method             = aws_api_gateway_method.root.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.proxy_bucket_name}/"
}

resource "aws_api_gateway_deployment" "s3_deployment" {
  depends_on = [
    aws_api_gateway_integration.s3_integration,
    aws_api_gateway_integration.root
  ]

  rest_api_id = aws_api_gateway_rest_api.s3_proxy.id

  # Sem este trigger o deployment so e criado uma vez: mudar rotas ou
  # integracoes depois disso alteraria a API, mas o stage continuaria
  # servindo o deployment antigo -- e a correcao da raiz acima nao
  # chegaria a um ambiente ja implantado.
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.any_method.id,
      aws_api_gateway_integration.s3_integration.id,
      aws_api_gateway_method.root.id,
      aws_api_gateway_integration.root.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "s3_stage" {
  deployment_id = aws_api_gateway_deployment.s3_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.s3_proxy.id
  stage_name    = "prod"
}

resource "aws_api_gateway_domain_name" "custom_domain" {
  depends_on = [aws_acm_certificate_validation.cert]

  domain_name     = var.proxy_domain
  regional_certificate_arn = aws_acm_certificate.cert.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
  api_id      = aws_api_gateway_rest_api.s3_proxy.id
  stage_name  = aws_api_gateway_stage.s3_stage.stage_name
}

resource "aws_route53_record" "api_dns" {
  zone_id = var.proxy_zone_id
  name    = var.proxy_domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.custom_domain.regional_zone_id
    evaluate_target_health = false
  }
}

# ============================================================
# CURINGA DA ZONA -- o fim do cache negativo
#
# Sem ele, consultar um nome ainda nao registrado devolve NXDOMAIN, e
# resolvedores guardam a resposta negativa por min(minimum do SOA, TTL
# do SOA) -- 15 minutos com os valores padrao do Route 53. O aluno
# testa o nome para ver se esta livre, registra, e continua quebrado
# por 15 minutos sem entender por que.
#
# Com o curinga nao existe mais resposta negativa nesta zona: todo nome
# resolve e serve o proprio site do gerenciador. Troca-se um negativo
# de 15 minutos por um positivo de 60 segundos.
#
# Registro explicito sempre vence curinga (RFC 4592), entao api.<zona>,
# https.<zona> e os nomes dos alunos continuam intactos -- o curinga so
# responde pelo que nao existe.
# ============================================================

resource "aws_api_gateway_domain_name" "wildcard_domain" {
  depends_on = [aws_acm_certificate_validation.cert]

  domain_name              = var.proxy_wildcard_domain
  regional_certificate_arn = aws_acm_certificate.cert.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "wildcard_mapping" {
  domain_name = aws_api_gateway_domain_name.wildcard_domain.domain_name
  api_id      = aws_api_gateway_rest_api.s3_proxy.id
  stage_name  = aws_api_gateway_stage.s3_stage.stage_name
}

resource "aws_route53_record" "wildcard_dns" {
  zone_id = var.proxy_zone_id
  name    = var.proxy_wildcard_domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.wildcard_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.wildcard_domain.regional_zone_id
    evaluate_target_health = false
  }
}
