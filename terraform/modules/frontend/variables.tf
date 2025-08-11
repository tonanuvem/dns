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

# --- Novas variáveis para a API Gateway ---
variable "api_gateway_invoke_url" {
  description = "URL de invocação da API Gateway para o backend."
  type        = string
}

variable "api_key_value" {
  description = "Valor da API Key para autenticação com o backend."
  type        = string
  sensitive   = true # Marque como sensível para não exibir no output do plan/apply
}

# Variável para depender do stage da API Gateway (para garantir que a API esteja implantada)
variable "api_gateway_stage_id" {
  description = "O ID do stage da API Gateway para criar uma dependência explícita."
  type        = string
}
