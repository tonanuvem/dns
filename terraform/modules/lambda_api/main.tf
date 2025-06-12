# Arquivo ZIP da função Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda_zip"
  output_path = "${path.module}/lambda_function.zip"
}

# Tabela DynamoDB
resource "aws_dynamodb_table" "registros_dns" {
  name           = "registros-dns"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "subdominio"

  attribute {
    name = "subdominio"
    type = "S"
  }
}

# Função Lambda
resource "aws_lambda_function" "gerenciador_dns" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "gerenciador-dns"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      TABELA_DYNAMODB     = aws_dynamodb_table.registros_dns.name
      ID_ZONA_HOSPEDADA   = var.id_zona_hospedada
      SENHA_COMPARTILHADA = var.senha_compartilhada
      NOME_DOMINIO        = var.nome_dominio
    }
  }
}

# IAM Role para a Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_gerenciador_dns_role"

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
}

# Política IAM para a Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_gerenciador_dns_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.registros_dns.arn
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.id_zona_hospedada}"
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

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "api-gerenciador-dns"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "X-Amz-Date", "Authorization", "X-Api-Key"]
  }
}

# Stage do API Gateway
resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.api.id
  name   = "prod"
  auto_deploy = true
}

# Integração da Lambda com o API Gateway
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Integração Lambda"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.gerenciador_dns.invoke_arn
}

# Permissão para o API Gateway invocar a Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gerenciador_dns.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Rota para todos os métodos HTTP
resource "aws_apigatewayv2_route" "registros" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /registros"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
} 