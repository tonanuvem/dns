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

# Bloqueio de acesso público ao bucket (para garantir que seja acessível como website)
# Necessário para permitir acesso público de website
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Política de bucket para permitir leitura pública dos objetos
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
  # ✅ Adicionado: Garante que o bloco de acesso público seja aplicado antes da política
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# Recurso nulo para executar o script de build do frontend
# Ele depende da API Gateway para garantir que a URL e a chave existam
resource "null_resource" "build_frontend" {
  # Garante que este recurso só seja executado após o API Gateway estar pronta
  # e que suas variáveis de output (como a URL) estejam disponíveis.
  # Substitua 'api_gateway_module' pelo nome real do módulo da sua API Gateway
  # no seu main.tf raiz, se ele tiver outputs que você precisa.
  depends_on = [
    var.api_gateway_stage_id # Depende do stage da API Gateway para garantir que a API esteja implantada
  ]

  # Triggers para refazer o build se as variáveis da API ou o código do frontend mudarem
  triggers = {
    api_url = var.api_gateway_invoke_url
    api_key = var.api_key_value
    # Adicione um hash do conteúdo do diretório frontend para que o build seja refeito
    # se qualquer arquivo do frontend mudar. Isso garante que o build seja sempre atualizado.
    # Usando path.root para construir o caminho relativo ao diretório do projeto
    frontend_content_hash = filemd5("${path.root}/../dns_admin/package.json")
    # ✅ Ativado: Hash do diretório inteiro para refazer o build em qualquer mudança de arquivo
    frontend_app_hash = sha1(join("", [for f in fileset("${path.root}/../dns_admin", "**") : filemd5("${path.root}/../dns_admin/${f}")]))
  }

  # Provisioner local-exec para executar o script Bash
  provisioner "local-exec" {
    # O working_dir deve ser a raiz do seu projeto Terraform (o diretório 'dns'),
    # para que os caminhos internos do script create_frontend_yarn.sh funcionem corretamente.
    working_dir = "${path.root}/.."

    # ✅ Adicionado: Comandos de debug para verificar o diretório e o script
    command = <<EOT
      echo "--- Debugging local-exec ---"
      echo "Current working directory:"
      pwd
      echo "Contents of scripts/ directory:"
      ls -l scripts/
      echo "Attempting to execute script:"
      bash ./scripts/create_frontend_yarn.sh --api-url ${var.api_gateway_invoke_url} --api-key ${var.api_key_value}
      echo "--- End Debugging ---"
    EOT
  }
}

# Upload dos arquivos do build para o S3
resource "aws_s3_bucket_object" "frontend_assets" {
  # ✅ CORREÇÃO 2: Ajuste do caminho para o diretório 'build' dentro de 'frontend_build'
  # path.module é 'terraform/modules/frontend'
  # O build está em 'terraform/frontend_build/build' (relativo à raiz do projeto)
  # Então, de path.module, precisamos subir dois níveis (../..) e descer para frontend_build/build
  for_each = fileset("${path.module}/../../frontend_build/build", "**")
  bucket   = aws_s3_bucket.frontend.id
  key      = each.value
  source   = "${path.module}/../../frontend_build/build/${each.value}"
  etag     = filemd5("${path.module}/../../frontend_build/build/${each.value}")
  content_type = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  acl      = "public-read"

  # Garante que o upload só ocorra após o build do frontend ser concluído
  depends_on = [null_resource.build_frontend]
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

  # Garante que o registro DNS só seja criado após o bucket ser configurado como website
  depends_on = [aws_s3_bucket_website_configuration.frontend]
}
