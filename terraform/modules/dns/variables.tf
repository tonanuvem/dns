variable "dns_nome_aluno" {
  description = "Nome do aluno para prefixar os recursos"
  type        = string
}

variable "dns_zone_id" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "dns_api_gateway_domain" {
  description = "Nome de domínio da API Gateway"
  type        = string
  default     = ""
}

variable "dns_api_gateway_domain_zone_id" {
  description = "ID da zona do domínio da API Gateway"
  type        = string
  default     = ""
}

variable "dns_frontend_domain" {
  description = "Nome de domínio do frontend"
  type        = string
}

variable "dns_frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  type        = string
}

variable "dns_frontend_website_endpoint" {
  description = "Endpoint do S3 website do frontend"
  type        = string
}

variable "dns_tags" {
  description = "Tags padrão para todos os recursos do módulo DNS"
  type        = map(string)
  default     = {}
} 