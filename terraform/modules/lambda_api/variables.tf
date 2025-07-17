variable "lambda_tags" {
  description = "Tags padrão para todos os recursos do módulo Lambda"
  type        = map(string)
  default     = {}
}

variable "lambda_nome_aluno" {
  description = "Nome do aluno para sufixar a função Lambda"
  type        = string
}

variable "lambda_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para registros DNS"
  type        = string
} 