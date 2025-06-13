variable "api_gateway_lambda_invoke_arn" {
  description = "ARN da função Lambda para invocação"
  type        = string
}

variable "api_gateway_nome_aluno" {
  description = "Nome do aluno para prefixo dos recursos"
  type        = string
}

variable "api_gateway_nome_dominio" {
  description = "Nome do domínio base para os recursos"
  type        = string
  default     = "dns.lab"
}

variable "api_gateway_tags" {
  description = "Tags padrão para todos os recursos do módulo API Gateway"
  type        = map(string)
  default     = {}
} 