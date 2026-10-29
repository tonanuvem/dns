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

  # Sem isto o Terraform so compara o CAMINHO do zip, que nunca muda:
  # editar a Lambda nao gerava diff nenhum e o apply publicava a versao
  # antiga em silencio. Observado em 28/10: o archive_file leu um hash
  # novo (o zip mudou), o plano nao trouxe a funcao, e a API continuou
  # ignorando o token -- rodando o codigo anterior.
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # filename = "${path.module}/fastapi_lambda_function.zip"
  function_name    = "gerenciador-dns-${var.lambda_nome_aluno}"
  role            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler         = "gerenciador_dns.lambda_handler"
  # python3.9 saiu do suporte da Lambda; a partir de dez/2025 a AWS
  # bloqueia ate a atualizacao de funcoes que ainda o usam.
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.registros_dns.name
      SENHA_API = var.senha_compartilhada
      TTL_DNS = var.ttl_dns
      # Era NAMESERVERS, mas o valor sempre foi o dominio da zona.
      DOMINIO = var.nome_dominio
      # So existe aqui: nao vai para o bundle do frontend.
      SENHA_ADMIN = var.senha_admin
      ZONA_ID = var.zona_id
    }
  }

  tags = merge(var.lambda_tags, {
    Name = "gerenciador-dns"
  })
}

# Obter o ID da conta atual
data "aws_caller_identity" "current" {}
