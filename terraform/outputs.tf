output "frontend_bucket_name" {
  description = "Nome do bucket S3 do frontend (exposto pelo root module para uso em scripts)"
  value       = module.frontend.frontend_bucket_name
} 