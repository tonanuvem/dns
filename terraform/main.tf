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

# Data source para obter o ID da conta atual
data "aws_caller_identity" "current" {}

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
  api_gateway_lambda_function_arn = module.lambda_api.lambda_function_arn
  api_gateway_nome_aluno        = var.nome_aluno
  api_gateway_nome_dominio      = var.nome_dominio
  api_gateway_tags             = var.tags
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
  frontend_tags         = var.tags
}

# =============================================
# Fluxo 4: DNS (Depende de API Gateway e Frontend)
# =============================================
# O módulo DNS depende de outros módulos para:
# - API Gateway: Criar registro DNS para a API
# - Frontend: Criar registro DNS para o frontend
# - Zona hospedada: Criar zona DNS para o aluno
module "dns" {
  source = "./modules/dns"

  dns_nome_aluno = var.nome_aluno
  dns_zone_id = data.aws_route53_zone.selecionada.zone_id
  
  # Dependências do API Gateway
  dns_api_gateway_domain = module.api_gateway.api_gateway_domain_name
  dns_api_gateway_domain_zone_id = module.api_gateway.api_gateway_domain_configuration[0].hosted_zone_id
  
  # Dependências do Frontend
  dns_frontend_domain = module.frontend.frontend_cloudfront_domain
  dns_frontend_domain_zone_id = module.frontend.frontend_cloudfront_zone_id
  
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

# Criar tabela DynamoDB para armazenar registros DNS
resource "aws_dynamodb_table" "registros_dns" {
  name           = "registros-dns-${var.nome_aluno}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "subdominio"
  range_key      = "endereco_ip"

  attribute {
    name = "subdominio"
    type = "S"
  }

  attribute {
    name = "endereco_ip"
    type = "S"
  }

  tags = merge(var.tags, {
    Aluno = var.nome_aluno
  })
}

# Criar função Lambda
resource "aws_lambda_function" "gerenciador_dns" {
  filename         = "../lambda/gerenciador_dns.zip"
  function_name    = "gerenciador-dns-${var.nome_aluno}"
  role            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler         = "gerenciador_dns.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.registros_dns.name
      SENHA_API      = var.senha_compartilhada
      TTL_DNS        = var.ttl_dns
      NAMESERVERS    = join(",", aws_route53_zone.zona_aluno.name_servers)
      ZONA_ID        = aws_route53_zone.zona_aluno.zone_id
    }
  }

  tags = merge(var.tags, {
    Aluno = var.nome_aluno
  })
}

# Criar API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "api-dns-${var.nome_aluno}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["*"]
  }

  tags = merge(var.tags, {
    Aluno = var.nome_aluno
  })
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id = aws_apigatewayv2_api.api.id
  name   = "prod"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  integration_uri    = aws_lambda_function.gerenciador_dns.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Permissões para a Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gerenciador_dns.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

