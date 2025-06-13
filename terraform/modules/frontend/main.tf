# Bucket S3 para o frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"

  tags = var.frontend_tags
}

# Configuração do bucket como website
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Registro DNS para o frontend (CNAME para o endpoint S3 website)
resource "aws_route53_record" "frontend" {
  name    = "frontend-${var.frontend_nome_aluno}"
  type    = "CNAME"
  zone_id = var.frontend_id_zona_hospedada
  ttl     = 60
  records = [aws_s3_bucket_website_configuration.frontend.website_endpoint]
}