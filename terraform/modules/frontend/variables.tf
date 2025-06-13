variable "frontend_nome_aluno" {
  description = "Nome do aluno para prefixo dos recursos"
  type        = string
}

variable "frontend_nome_dominio" {
  description = "Nome do domínio base para os recursos"
  type        = string
  default     = "dns.lab"
}

variable "frontend_id_zona_hospedada" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "frontend_tags" {
  description = "Tags padrão para todos os recursos do módulo Frontend"
  type        = map(string)
  default     = {}
}

variable "enable_https" {
  description = "Habilita HTTPS no frontend (CloudFront + ACM)"
  type        = bool
  default     = false
}