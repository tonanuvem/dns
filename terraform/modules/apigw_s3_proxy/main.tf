provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.proxy_domain
  validation_method = "DNS"
  tags              = var.proxy_tags
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
  provider                = aws.us_east_1
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

resource "aws_api_gateway_deployment" "s3_deployment" {
  depends_on = [
    aws_api_gateway_integration.s3_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.s3_proxy.id
  stage_name  = "prod"
}

resource "aws_api_gateway_domain_name" "custom_domain" {
  depends_on = [aws_acm_certificate_validation.cert]

  domain_name     = var.proxy_domain
  certificate_arn = aws_acm_certificate.cert.arn

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  domain_name = aws_api_gateway_domain_name.custom_domain.domain_name
  rest_api_id = aws_api_gateway_rest_api.s3_proxy.id
  stage_name  = aws_api_gateway_deployment.s3_deployment.stage_name
}

resource "aws_route53_record" "api_dns" {
  zone_id = var.proxy_zone_id
  name    = var.proxy_domain
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.custom_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.custom_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}
