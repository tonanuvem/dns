############################
# SUFIXO NUMÉRICO ALEATÓRIO
############################
resource "random_integer" "frontend" {
  min = 0
  max = 99
}

############################
# DOMÍNIO FINAL (bucket = cname)
############################
locals {
  frontend_domain = "www${random_integer.frontend.result}.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"
}

############################
# BUCKET S3 (STATIC WEBSITE)
############################
resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_domain
  tags   = var.frontend_tags
}

############################
# OWNERSHIP CONTROLS
############################
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

############################
# BLOQUEIO DE ACESSO PÚBLICO
############################
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

############################
# ACL DO BUCKET
############################
resource "aws_s3_bucket_acl" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.frontend,
    aws_s3_bucket_public_access_block.frontend
  ]
}

############################
# WEBSITE CONFIG
############################
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

############################
# ESPERA PROPAGAÇÃO
############################
resource "time_sleep" "wait_for_s3_block_config" {
  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend
  ]

  create_duration = "15s"
}

############################
# POLICY PÚBLICA (READ)
############################
resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    time_sleep.wait_for_s3_block_config
  ]
}

############################
# BUILD DO FRONTEND
############################
resource "null_resource" "build_frontend" {
  depends_on = [
    var.api_gateway_stage_id
  ]

  triggers = {
    api_url = var.api_gateway_invoke_url
    api_key = var.api_key_value

    # O hash observava "../frontend_app", pasta que nao existe: o
    # resultado era sempre da39a3ee... (o sha1 da string vazia), entao
    # editar o frontend nunca disparava um novo build. O codigo esta em
    # dns_admin/, e o padrao lista so o que entra no bundle -- sem o
    # filtro, node_modules/ e build/ tornariam o hash inviavel.
    frontend_app_hash = sha1(join("", [
      for f in fileset("${path.root}/../dns_admin", "{src/**,public/**,index.html,package.json,vite.config.js}") :
      filemd5("${path.root}/../dns_admin/${f}")
    ]))
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = <<EOT
      bash ./scripts/create_frontend_yarn.sh \
        --api-url ${var.api_gateway_invoke_url} \
        --api-key ${var.api_key_value}
    EOT
  }
}

############################
# UPLOAD DOS ARQUIVOS
#
# O upload usava aws_s3_object com for_each sobre um fileset do
# frontend_build. O fileset e resolvido no PLAN, antes de o
# null_resource acima gerar o build -- entao no primeiro apply a pasta
# nem existia, nenhum objeto entrava no plano e o site subia vazio
# (bucket criado, CNAME criado, zero arquivos).
#
# O sync roda no apply, depois do build, e o --delete remove sobras de
# builds anteriores. O proprio CLI define o Content-Type pela extensao,
# o que tornou o mapa de mime types desnecessario.
############################
resource "null_resource" "upload_frontend" {
  triggers = {
    bucket   = aws_s3_bucket.frontend.id
    build_id = null_resource.build_frontend.id
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = "aws s3 sync ./terraform/frontend_build s3://${aws_s3_bucket.frontend.id} --delete"
  }

  depends_on = [
    null_resource.build_frontend,
    aws_s3_bucket_policy.frontend_public_read,
    aws_s3_bucket_website_configuration.frontend
  ]
}

############################
# ROUTE53 (CNAME → S3 WEBSITE)
############################
resource "aws_route53_record" "frontend" {
  name    = local.frontend_domain
  type    = "CNAME"
  zone_id = var.frontend_id_zona_hospedada
  ttl     = 60

  records = [
    aws_s3_bucket_website_configuration.frontend.website_endpoint
  ]

  depends_on = [
    aws_s3_bucket_website_configuration.frontend,
    aws_s3_bucket_policy.frontend_public_read
  ]
}
