variable "nome_aluno" {
  description = "Nome do aluno para prefixar os recursos"
  type        = string
}

variable "zone_id" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "api_gateway_domain" {
  description = "Nome de domínio da API Gateway"
  type        = string
}

variable "api_gateway_domain_zone_id" {
  description = "ID da zona do domínio da API Gateway"
  type        = string
}

variable "frontend_domain" {
  description = "Nome de domínio do frontend"
  type        = string
}

variable "frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
} 