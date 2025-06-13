variable "lambda_nome_dominio" {
  description = "Nome do domínio base (ex: lab.tonanuvem.com)"
  type        = string
}

variable "lambda_id_zona_hospedada" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "lambda_senha_compartilhada" {
  description = "Senha compartilhada para autenticação"
  type        = string
  sensitive   = true
}

variable "lambda_tags" {
  description = "Tags padrão para todos os recursos do módulo Lambda"
  type        = map(string)
  default     = {}
} 