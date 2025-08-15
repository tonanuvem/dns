provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Política para permitir ações CloudFront necessárias
resource "aws_iam_policy" "allow_cloudfront_create" {
  name        = "AllowCloudFrontCreate"
  description = "Permissões para criação e gerenciamento de distribuições CloudFront"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:ListDistributions",
          "cloudfront:GetDistributionConfig"
        ]
        Resource = "*"
      }
    ]
  })
}

# Anexar a política ao role informado na variável
resource "aws_iam_role_policy_attachment" "attach_cloudfront_policy" {
  role       = var.cloudfront_iam_role_name
  policy_arn = aws_iam_policy.allow_cloudfront_create.arn
}

# Certificado ACM na região us-east-1 (exigido pelo CloudFront)
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = "www.${var.cloudfront_nome_aluno}.${var.cloudfront_nome_dominio}"
  validation_method = "DNS"
  tags              = var.cloudfront_tags
}

# Registro DNS para validação do certificado
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.cloudfront_id_zona_hospedada
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Validação do certificado
resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  depends_on = [aws_route53_record.cert_validation]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["www.${var.cloudfront_nome_aluno}.${var.cloudfront_nome_dominio}"]

  origin {
    domain_name = var.cloudfront_s3_website_endpoint
    origin_id   = "S3Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.frontend.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"
  tags        = var.cloudfront_tags

  depends_on = [
    aws_acm_certificate_validation.frontend,
    aws_iam_role_policy_attachment.attach_cloudfront_policy
  ]
}

# DNS apontando para CloudFront
resource "aws_route53_record" "frontend_https" {
  zone_id = var.cloudfront_id_zona_hospedada
  name    = "www.${var.cloudfront_nome_aluno}.${var.cloudfront_nome_dominio}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_cloudfront_distribution.frontend]
}
