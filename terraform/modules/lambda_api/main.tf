# Tabela DynamoDB para armazenar registros DNS
resource "aws_dynamodb_table" "registros_dns" {
  name           = var.lambda_dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "alias"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "alias"
    type = "S"
  }

  tags = merge(var.lambda_tags, {
    Name = "registros-dns"
  })
}

# Arquivo ZIP da função Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  #source_file = "${path.root}/../lambda_zip/gerenciador_dns.zip"
  source_file = "${path.root}/../lambda/gerenciador_dns.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Função Lambda
resource "aws_lambda_function" "gerenciador_dns" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "gerenciador-dns-${var.lambda_nome_aluno}"
  role            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler         = "gerenciador_dns.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.registros_dns.name
      SENHA_API = var.senha_compartilhada
    }
  }

  tags = merge(var.lambda_tags, {
    Name = "gerenciador-dns"
  })
}

# Obter o ID da conta atual
data "aws_caller_identity" "current" {}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "api-gerenciador-dns"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age      = 300
  }

  tags = merge(var.lambda_tags, {
    Name = "api-gerenciador-dns"
  })
}

# Integração da API Gateway com a função Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.gerenciador_dns.invoke_arn
}

# Rota da API Gateway
resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Stage da API Gateway
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id = aws_apigatewayv2_api.api.id
  name   = "prod"
  auto_deploy = true

  tags = merge(var.lambda_tags, {
    Name = "api-gerenciador-dns-stage"
  })
}

# Permissão para a API Gateway invocar a função Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gerenciador_dns.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}