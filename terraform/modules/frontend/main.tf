# Gerar sufixo aleatório para o nome do bucket
# Este recurso random_id será removido, pois o nome do bucket será fixo para o CNAME.
# resource "random_id" "frontend_bucket" {
#   byte_length = 4
# }

# Bucket S3 para o frontend
resource "aws_s3_bucket" "frontend" {
  # ✅ CORREÇÃO 1: Nome do bucket deve ser igual ao CNAME para Static Website Hosting
  bucket = "www.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"

  tags = var.frontend_tags
}

# ✅ NOVA CORREÇÃO: Configuração explícita de ACL do bucket
resource "aws_s3_bucket_acl" "frontend" {
  bucket     = aws_s3_bucket.frontend.id
  acl        = "public-read"
  
  depends_on = [
    aws_s3_bucket.frontend,
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend
  ]
}

# ✅ NOVA CORREÇÃO: Configuração de ownership controls para permitir ACLs
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket.frontend]
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

  # Garantir que seja criado após o bucket
  depends_on = [aws_s3_bucket.frontend]
}

# ✅ CORREÇÃO CRÍTICA: Bloqueio de acesso público ao bucket PRIMEIRO
# Necessário para permitir acesso público de website
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # Garantir que seja criado após o bucket
  depends_on = [aws_s3_bucket.frontend]
}

# ✅ NOVO: Recurso para aguardar a propagação das configurações do S3
resource "time_sleep" "wait_for_s3_block_config" {
  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_ownership_controls.frontend
  ]
  create_duration = "15s"
}

# ✅ CORREÇÃO CRÍTICA: Política de bucket DEPOIS do bloqueio estar configurado
resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
  
  # ✅ CORREÇÃO: Dependências explícitas para garantir ordem correta
  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    time_sleep.wait_for_s3_block_config
  ]
}

# Recurso nulo para executar o script de build do frontend
# Ele depende da API Gateway para garantir que a URL e a chave existam
resource "null_resource" "build_frontend" {
  # Garante que este recurso só seja executado após o API Gateway estar pronta
  # e que suas variáveis de output (como a URL) estejam disponíveis.
  depends_on = [
    var.api_gateway_stage_id # Depende do stage da API Gateway para garantir que a API esteja implantada
  ]

  # Triggers para refazer o build se as variáveis da API ou o código do frontend mudarem
  triggers = {
    api_url = var.api_gateway_invoke_url
    api_key = var.api_key_value
    # ✅ CORREÇÃO: Ajuste o caminho para a pasta do código-fonte da sua aplicação React.
    # Substitua `../frontend_app` pelo caminho correto.
    frontend_app_hash = sha1(join("", [for f in fileset("${path.root}/../frontend_app", "**") : filemd5("${path.root}/../frontend_app/${f}")]))
  }

  # Provisioner local-exec para executar o script Bash
  provisioner "local-exec" {
    working_dir = "${path.root}/.."

    command = <<EOT
      # echo "--- Debugging local-exec ---"
      # echo "Current working directory:"
      # pwd
      # echo "Contents of scripts/ directory:"
      # ls -l scripts/
      # echo "Attempting to execute script:"
      bash ./scripts/create_frontend_yarn.sh --api-url ${var.api_gateway_invoke_url} --api-key ${var.api_key_value}
      # echo "--- End Debugging ---"
    EOT
  }
}

# ✅ CORREÇÃO: Mudança de aws_s3_bucket_object para aws_s3_object (resource não depreciado)
resource "aws_s3_object" "frontend_assets" {
  # ✅ CORREÇÃO: Ajuste do caminho para a pasta 'frontend_build'.
  # path.module é 'terraform/modules/frontend'
  # A pasta de build está em 'terraform/frontend_build' (relativo à raiz do projeto)
  for_each = fileset("${path.module}/../../frontend_build", "**")
  
  bucket   = aws_s3_bucket.frontend.id
  key      = each.value
  # ✅ CORREÇÃO: O caminho da 'source' também foi corrigido.
  source   = "${path.module}/../../frontend_build/${each.value}"
  
  etag     = filemd5("${path.module}/../../frontend_build/${each.value}")
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  # ✅ CORREÇÃO CRÍTICA: Removido ACL - não é mais necessário com a política de bucket
  # acl      = "public-read"  # ← Esta linha causa o erro

  # ✅ CORREÇÃO: Garantir que a política esteja aplicada antes do upload
  depends_on = [
    null_resource.build_frontend,
    aws_s3_bucket_policy.frontend_public_read
  ]
}

# Mime types para o upload (para que o navegador interprete corretamente os arquivos)
locals {
  mime_types = {
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "gif"  = "image/gif"
    "svg"  = "image/svg+xml"
    "ico"  = "image/x-icon"
    # Adicione mais tipos conforme necessário
  }
}

# Registro DNS para o frontend (CNAME para o endpoint S3 website)
# Se você for usar HTTPS com CloudFront, este registro será diferente (Alias para CloudFront)
resource "aws_route53_record" "frontend" {
  name    = "www.${var.frontend_nome_aluno}.${var.frontend_nome_dominio}"
  type    = "CNAME"
  zone_id = var.frontend_id_zona_hospedada
  ttl     = 60
  records = [aws_s3_bucket_website_configuration.frontend.website_endpoint]

  # ✅ CORREÇÃO: Dependências mais explícitas
  depends_on = [
    aws_s3_bucket_website_configuration.frontend,
    aws_s3_bucket_policy.frontend_public_read
  ]
}