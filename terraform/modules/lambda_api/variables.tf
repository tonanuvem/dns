variable "nome_dominio" {
  description = "Nome do domínio base (ex: lab.tonanuvem.com)"
  type        = string
}

variable "id_zona_hospedada" {
  description = "ID da zona hospedada no Route 53"
  type        = string
}

variable "senha_compartilhada" {
  description = "Senha compartilhada para autenticação"
  type        = string
  sensitive   = true
} 