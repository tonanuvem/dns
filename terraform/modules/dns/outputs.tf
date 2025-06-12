output "api_record_name" {
  description = "Nome do registro DNS da API"
  value       = aws_route53_record.api.name
}

output "frontend_record_name" {
  description = "Nome do registro DNS do frontend"
  value       = aws_route53_record.frontend.name
} 