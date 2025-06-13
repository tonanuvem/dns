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

variable "api_gateway_lambda_function_arn" {
  description = "ARN da função Lambda"
  type        = string
}

variable "api_gateway_lambda_function_name" {
  description = "Nome da função Lambda"
  type        = string
}

variable "api_gateway_zone_id" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "api_gateway_tags" {
  description = "Tags padrão para todos os recursos"
  type        = map(string)
  default     = {}
} 