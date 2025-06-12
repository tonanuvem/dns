terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# Data source para obter a zona hospedada
data "aws_route53_zone" "selecionada" {
  zone_id = var.id_zona_hospedada
}

# Módulo para criar a função Lambda
module "lambda_api" {
  source = "./modules/lambda_api"

  nome_dominio = var.nome_dominio
  id_zona_hospedada = data.aws_route53_zone.selecionada.zone_id
  senha_compartilhada = var.senha_compartilhada
  tags = var.tags
}

# Módulo para criar a API Gateway
module "api_gateway" {
  source = "./modules/api_gateway"

  lambda_invoke_arn = module.lambda_api.lambda_function_invoke_arn
  nome_aluno        = var.nome_aluno
  nome_dominio      = var.nome_dominio
  tags             = var.tags
}

# Módulo para criar o frontend
module "frontend" {
  source = "./modules/frontend"

  nome_aluno   = var.nome_aluno
  nome_dominio = var.nome_dominio
  tags         = var.tags
}

# Módulo para criar os registros DNS
module "dns" {
  source = "./modules/dns"

  nome_aluno = var.nome_aluno
  zone_id = data.aws_route53_zone.selecionada.zone_id
  api_gateway_domain = module.api_gateway.domain_name
  api_gateway_domain_zone_id = module.api_gateway.domain_name_configuration[0].hosted_zone_id
  frontend_domain = module.frontend.cloudfront_domain_name
  frontend_domain_zone_id = module.frontend.cloudfront_hosted_zone_id
  tags = var.tags
}

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
  role            = aws_iam_role.lambda_role.arn
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

# IAM Role para a Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_gerenciador_dns_role_${var.nome_aluno}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Aluno = var.nome_aluno
  })
}

# Política IAM para a Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_gerenciador_dns_policy_${var.nome_aluno}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.registros_dns.arn
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${aws_route53_zone.zona_aluno.zone_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Outputs
output "api_endpoint" {
  description = "Endpoint da API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "frontend_url" {
  description = "URL do frontend"
  value       = module.frontend.frontend_url
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = module.lambda_api.dynamodb_table_name
}

output "nameservers" {
  value = aws_route53_zone.zona_aluno.name_servers
  description = "Nameservers da zona hospedada"
}

output "zona_id" {
  value = aws_route53_zone.zona_aluno.zone_id
  description = "ID da zona hospedada"
}

output "dynamodb_table" {
  value = aws_dynamodb_table.registros_dns.name
  description = "Nome da tabela DynamoDB"
}

# Variáveis
variable "nome_aluno" {
  description = "Nome do aluno para prefixo dos recursos"
  type        = string
}

variable "nome_dominio" {
  description = "Nome do domínio base para os recursos"
  type        = string
  default     = "dns.lab"
}

variable "tags" {
  description = "Tags padrão para todos os recursos"
  type        = map(string)
  default     = {}
} 