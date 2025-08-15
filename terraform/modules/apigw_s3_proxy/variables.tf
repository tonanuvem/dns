variable "proxy_bucket_name" {
  description = "Bucket S3 como endpoint website (ex: www.aluno.lab.tonanuvem.com.s3-website-us-east-1.amazonaws.com)"
  type        = string
}

variable "proxy_domain" {
  description = "Nome do domínio customizado (ex: www.aluno.lab.tonanuvem.com)"
  type        = string
}

variable "proxy_zone_id" {
  description = "Zone ID do domínio no Route53"
  type        = string
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags aplicadas a recursos do módulo"
}