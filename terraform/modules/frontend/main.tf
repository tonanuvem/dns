# Gerar sufixo aleatório para o nome do bucket
resource "random_id" "frontend_bucket" {
  byte_length = 4
}

# Bucket S3 para o frontend
resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${var.frontend_nome_aluno}.${var.frontend_nome_dominio}-${random_id.frontend_bucket.hex}"

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
  name    = "www.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"
  type    = "CNAME"
  zone_id = var.frontend_id_zona_hospedada
  ttl     = 60
  records = [aws_s3_bucket_website_configuration.frontend.website_endpoint]
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}