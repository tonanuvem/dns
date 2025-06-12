output "function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.arn
}

output "function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.function_name
}

output "invoke_arn" {
  description = "ARN para invocação da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.invoke_arn
} 