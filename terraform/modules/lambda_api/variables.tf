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

variable "senha_compartilhada" {
  description = "Senha compartilhada para autenticação na API"
  type        = string
  sensitive   = true
}

variable "ttl_dns" {
  description = "Tempo de vida (TTL) dos registros DNS"
  type        = number
}

variable "nome_dominio" {
  description = "Nameservers para a zona DNS"
  type        = string
}

variable "zona_id" {
  description = "ID da zona DNS"
  type        = string
}
