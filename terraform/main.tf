terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Os quatro abaixo eram usados pelos modulos sem estarem
    # declarados, entao o init resolvia "latest" a cada execucao e a
    # turma podia acabar com versoes diferentes entre si.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
  required_version = ">= 1.2.0"

  # Backend parcial: o bucket e a regiao chegam pelo deploy.sh, que
  # deriva o nome do account id (o mesmo padrao do repositorio config).
  #
  # Com o state local, uma VM recriada ou um $HOME perdido levava junto
  # o unico registro do que existe na conta -- e os recursos do Route 53
  # da turma ficariam orfaos, sem destroy possivel.
  backend "s3" {}
}

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1"
}

# ============================================================
# SENHA DE INSTRUTOR
#
# Gerada aqui, e nao pelo config.sh, para ter uma fonte unica: o
# random_password vive no state (S3), entao sobrevive a perda da VM e
# e estavel entre applies. Antes ela nascia no config.sh e so existia
# no terraform.tfvars de uma VM -- perdida a VM, perdida a senha.
#
# var.senha_admin sobrescreve, para quando voce quiser uma senha
# escolhida a mao.
#
# Fica no state em texto claro -- mas isso ja valia para a senha da
# turma e para as variaveis de ambiente da Lambda, que tambem estao
# la. O bucket do state e privado.
# ============================================================

resource "random_password" "admin" {
  length  = 12
  special = false
  upper   = false
}

locals {
  senha_admin = var.senha_admin != "" ? var.senha_admin : "instrutor-${random_password.admin.result}"
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
  senha_compartilhada = var.senha_compartilhada
  senha_admin = local.senha_admin
  ttl_dns = var.ttl_dns
  nome_dominio = "${var.nome_aluno}.${var.nome_dominio}"
  zona_id = var.id_zona_hospedada
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
  api_gateway_lambda_function_name = module.lambda_api.lambda_function_name
  api_gateway_nome_aluno        = var.nome_aluno
  api_gateway_nome_dominio      = var.nome_dominio
  api_gateway_tags              = var.tags
  api_gateway_id_zona_hospedada = data.aws_route53_zone.selecionada.zone_id

  # Se você estiver criando uma API Key via Terraform, ela deve ser um output do seu módulo api_gateway.
  # Por exemplo, se seu módulo api_gateway tivesse um output chamado 'api_key_value':
  # api_key_value = module.api_gateway.api_key_value
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

  frontend_nome_aluno        = var.nome_aluno
  frontend_nome_dominio      = var.nome_dominio
  frontend_id_zona_hospedada = data.aws_route53_zone.selecionada.zone_id
  frontend_tags              = var.tags

  # Passa os outputs da API Gateway para o módulo frontend
  # Estes são os valores que serão injetados no build do React-Admin
  api_gateway_invoke_url = module.api_gateway.api_invoke_url
  # Se você estiver criando a API Key via Terraform, use o output correspondente.
  # Exemplo: api_key_value = aws_apigatewayv2_api_key.api_key.value
  # Se a API Key for gerenciada manualmente ou via variável, passe-a aqui:
  api_key_value          = var.senha_compartilhada
  api_gateway_stage_id   = module.api_gateway.api_stage_id # Passa o ID do stage para dependência
}

# =============================================
# Fluxo 4: Proxy (Dependente do Frontend)
# =============================================
# Este módulo é responsável pela configuração dos:
# API Gateway como proxy HTTPS para o bucket S3 público 
# (sem Lambda, usando integração HTTP direta).
module "apigw_s3_proxy" {
  source = "./modules/apigw_s3_proxy"

  proxy_bucket_name = module.frontend.frontend_website_endpoint # ex: "www7.aluno.lab.tonanuvem.com.s3-website-us-east-1.amazonaws.com"

  # Era "www2" fixo, e o bucket carrega um sufixo sorteado de 0 a 99:
  # um sorteio de 2 colocaria um CNAME (frontend -> S3) e um A-alias
  # (proxy -> API Gateway) com o mesmo nome na zona, quebrando o apply.
  #
  # O sufixo existe porque nome de bucket S3 e global na AWS. Este
  # hostname nao e um bucket -- e um alias de API Gateway, que so
  # precisa ser unico DENTRO da zona. Entao ele fica estatico e sem
  # numero: nunca colide com wwwNN, e continua conhecido em tempo de
  # plan, que e o que o for_each do cert_validation exige.
  proxy_domain  = "https.${var.nome_aluno}.${var.nome_dominio}"

  # Qualquer nome ainda nao registrado cai aqui em vez de devolver
  # NXDOMAIN. Ver o bloco do curinga no modulo.
  proxy_wildcard_domain = "*.${var.nome_aluno}.${var.nome_dominio}"
  proxy_zone_id = data.aws_route53_zone.selecionada.zone_id
  proxy_tags    = var.tags
}
