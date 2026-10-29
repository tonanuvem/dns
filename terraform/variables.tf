variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "nome_aluno" {
  description = "Nome do aluno para prefixo dos recursos"
  type        = string
}

# O default era "dns.lab", que nao existe e divergia do valor usado
# pelo config.sh e pelo tfvars.
variable "nome_dominio" {
  description = "Domínio base, delegado para a conta do laboratório"
  type        = string
  default     = "lab.tonanuvem.com"
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
# Senha do instrutor, para editar ou apagar pela interface um registro
# criado por aluno. Precisa ser DIFERENTE de senha_compartilhada: aquela
# e a senha da turma, vai no bundle publico do frontend e embutida no
# dns.sh. Vazia desliga o override.
variable "senha_admin" {
  description = "Senha de instrutor (NUNCA entra no bundle do frontend)"
  type        = string
  sensitive   = true
  default     = ""
}
