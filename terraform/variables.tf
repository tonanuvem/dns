variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

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

variable "senha_compartilhada" {
  description = "Senha compartilhada para autenticação na API"
  type        = string
  sensitive   = true
}

variable "ttl_dns" {
  description = "TTL dos registros DNS em segundos"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags padrão para todos os recursos"
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "ID da conta AWS"
  type        = string
}