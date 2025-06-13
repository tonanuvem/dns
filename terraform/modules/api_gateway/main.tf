# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "api-gerenciador-dns"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age      = 300
  }

  tags = var.tags
}

# Integração da API Gateway com a função Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration"
  integration_method = "POST"
  integration_uri    = var.lambda_invoke_arn
}

# Rota da API Gateway
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Stage da API Gateway
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id = aws_apigatewayv2_api.api.id
  name   = "prod"
  auto_deploy = true

  tags = var.tags
}

# Certificado ACM para a API
resource "aws_acm_certificate" "api" {
  domain_name       = "api.${var.nome_aluno}.${var.nome_dominio}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "api-${var.nome_aluno}-cert"
  })
}

# Validação do certificado
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_acm_certificate.api.domain_validation_options : record.resource_record_name]
}

# Domínio personalizado da API
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.${var.nome_aluno}.${var.nome_dominio}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# Mapeamento da API para o domínio personalizado
resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.domain_name
  stage       = aws_apigatewayv2_stage.lambda_stage.id
}

# Registro DNS para a API
resource "aws_route53_record" "api" {
  name    = aws_apigatewayv2_domain_name.api.domain_name
  type    = "A"
  zone_id = var.id_zona_hospedada

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
} 