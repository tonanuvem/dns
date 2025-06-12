# Tabela DynamoDB para armazenar registros DNS
resource "aws_dynamodb_table" "registros_dns" {
  name           = "registros-dns"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "alias"
  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "alias"
    type = "S"
  }

  tags = {
    Name = "registros-dns"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Arquivo ZIP da função Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda_zip/gerenciador_dns.zip"
  output_path = "${path.module}/lambda_function.zip"
}

# Função Lambda
resource "aws_lambda_function" "gerenciador_dns" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "gerenciador-dns"
  role            = aws_iam_role.lambda_role.arn
  handler         = "gerenciador_dns.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.registros_dns.name
    }
  }

  tags = {
    Name = "gerenciador-dns"
  }
}

# Role IAM para a função Lambda
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

  tags = {
    Name = "lambda-gerenciador-dns-role"
  }
}

# Política IAM para a função Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_gerenciador_dns_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.registros_dns.arn
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
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age      = 300
  }

  tags = {
    Name = "api-gerenciador-dns"
  }
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

  tags = {
    Name = "api-gerenciador-dns-stage"
  }
}

# Permissão para a API Gateway invocar a função Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gerenciador_dns.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Outputs
output "lambda_function_arn" {
  value = aws_lambda_function.gerenciador_dns.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.gerenciador_dns.function_name
}

output "lambda_function_invoke_arn" {
  value = aws_lambda_function.gerenciador_dns.invoke_arn
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.registros_dns.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.registros_dns.arn
} 