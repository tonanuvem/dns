variable "nome_aluno" {
  description = "Nome do aluno para prefixo dos recursos"
  type        = string
}

variable "nome_dominio" {
  description = "Nome do domínio base para os recursos"
  type        = string
  default     = "dns.lab"
}

variable "id_zona_hospedada" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "tags" {
  description = "Tags padrão para todos os recursos"
  type        = map(string)
  default     = {}
} 