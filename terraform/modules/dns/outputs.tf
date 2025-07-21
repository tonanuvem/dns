output "dns_api_record_name" {
  description = "Nome do registro DNS da API"
  value       = length(aws_route53_record.api) > 0 ? aws_route53_record.api[0].name : ""
}

output "dns_frontend_record_name" {
  description = "Nome do registro DNS do frontend"
  value       = aws_route53_record.frontend.name
}

output "dns_zone_id" {
  description = "ID da zona hospedada"
  value       = var.dns_zone_id
} 