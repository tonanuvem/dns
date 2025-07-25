terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1"
}

# Data source para obter a zona hospedada
data "aws_route53_zone" "selecionada" {
  zone_id = var.id_zona_hospedada
}

# =============================================
# Fluxo 1: Lambda API (Base da Infraestrutura)
# =============================================
# O módulo Lambda API é a base da infraestrutura, fornecendo:
# - Função Lambda para gerenciamento DNS
# - Tabela DynamoDB para armazenamento dos registros
# - ARN da função para integração com API Gateway
module "lambda_api" {
  source = "./modules/lambda_api"
  lambda_tags = var.tags
  lambda_nome_aluno = var.nome_aluno
  lambda_dynamodb_table_name = "registros-dns-${var.nome_aluno}"
}

# =============================================
# Fluxo 2: API Gateway (Depende do Lambda API)
# =============================================
# O módulo API Gateway depende do Lambda API para:
# - Integração com a função Lambda (lambda_invoke_arn)
# - Configuração do endpoint HTTP
# - Configuração do domínio personalizado
module "api_gateway" {
  source = "./modules/api_gateway"

  api_gateway_lambda_invoke_arn = module.lambda_api.lambda_invoke_arn
  api_gateway_nome_aluno        = var.nome_aluno
  api_gateway_nome_dominio      = var.nome_dominio
  api_gateway_tags              = var.tags
  api_gateway_id_zona_hospedada = data.aws_route53_zone.selecionada.zone_id
}

# =============================================
# Fluxo 3: Frontend (Independente)
# =============================================
# O módulo Frontend é independente e fornece:
# - Bucket S3 para hospedagem estática
# - Distribuição CloudFront para CDN
# - Certificado SSL para HTTPS
module "frontend" {
  source = "./modules/frontend"

  frontend_nome_aluno   = var.nome_aluno
  frontend_nome_dominio = var.nome_dominio
  frontend_id_zona_hospedada = data.aws_route53_zone.selecionada.zone_id
  frontend_tags         = var.tags
}

# =============================================
# Fluxo 4: DNS (Dependente do Frontend e API Gateway)
# =============================================
# O módulo DNS é dependente e fornece:
# - Registros DNS para API Gateway
# - Registros DNS para Frontend
module "dns" {
  source = "./modules/dns"

  dns_nome_aluno = var.nome_aluno
  dns_zone_id = data.aws_route53_zone.selecionada.zone_id
  
  # Valores do API Gateway
  # dns_api_gateway_domain = module.api_gateway.api_gateway_domain_name
  # dns_api_gateway_domain_zone_id = module.api_gateway.api_gateway_domain_zone_id
  
  # Valores do Frontend
  dns_frontend_domain = module.frontend.frontend_domain_name
  dns_frontend_domain_zone_id = module.frontend.frontend_domain_zone_id
  dns_frontend_website_endpoint = module.frontend.frontend_website_endpoint
  
  dns_tags = var.tags
}

# =============================================
# Recursos Adicionais
# =============================================

# Criar zona hospedada para o aluno
resource "aws_route53_zone" "zona_aluno" {
  name = "${var.nome_aluno}.${var.nome_dominio}"
  comment = "Zona hospedada para ${var.nome_aluno}"
  
  tags = merge(var.tags, {
    Aluno = var.nome_aluno
  })
}

# Removi a tabela DynamoDB do root, pois agora está no módulo lambda_api.

