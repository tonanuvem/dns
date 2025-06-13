output "dns_api_record_name" {
  description = "Nome do registro DNS da API"
  value       = aws_route53_record.api.name
}

output "dns_frontend_record_name" {
  description = "Nome do registro DNS do frontend"
  value       = aws_route53_record.frontend.name
}

output "dns_zone_id" {
  description = "ID da zona hospedada"
  value       = var.zone_id
} 