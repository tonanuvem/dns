output "frontend_domain_name" {
  description = "Nome de domínio do frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_domain_zone_id" {
  description = "ID da zona do domínio do frontend"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

output "frontend_url" {
  description = "URL do frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_bucket_name" {
  description = "Nome do bucket S3 do frontend"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN do bucket S3 do frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_distribution_id" {
  description = "ID da distribuição CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
} 