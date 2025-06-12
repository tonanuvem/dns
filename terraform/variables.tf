variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "nome_aluno" {
  description = "Nome do aluno para criar o subdomínio (ex: joao, maria, etc)"
  type        = string
}

variable "nome_dominio" {
  description = "Nome do domínio base (ex: lab.tonanuvem.com)"
  type        = string
  default     = "lab.tonanuvem.com"
}

variable "id_zona_hospedada" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "senha_compartilhada" {
  description = "Senha para autenticação na API"
  type        = string
  sensitive   = true
}

variable "ttl_dns" {
  description = "TTL dos registros DNS em segundos"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags para os recursos AWS"
  type        = map(string)
  default = {
    Project     = "GerenciadorDNS"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
} 