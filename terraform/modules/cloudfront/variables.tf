variable "cloudfront_nome_aluno" {
  type        = string
  description = "Prefixo do subdomínio (ex: www.aluno)"
}

variable "cloudfront_nome_dominio" {
  type        = string
  description = "Domínio principal (ex: lab.tonanuvem.com)"
}

variable "cloudfront_id_zona_hospedada" {
  type        = string
  description = "ID da zona hospedada no Route 53"
}

variable "cloudfront_s3_website_endpoint" {
  type        = string
  description = "Endpoint do site S3 (ex: www.aluno.lab.tonanuvem.com.s3-website-...)"
}

variable "cloudfront_tags" {
  type        = map(string)
  default     = {}
  description = "Tags para os recursos"
}

variable "cloudfront_iam_role_name" {
  type        = string
  description = "Nome do IAM Role para anexar a política CloudFront (ex: voclabs)"
  default     = "voclabs"
}
