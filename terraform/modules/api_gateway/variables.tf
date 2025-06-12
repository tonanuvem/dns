variable "nome_aluno" {
  description = "Nome do aluno para prefixar os recursos"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN da função Lambda"
  type        = string
}

variable "lambda_function_name" {
  description = "Nome da função Lambda"
  type        = string
}

variable "zone_id" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
} 