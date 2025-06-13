output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.arn
}

output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.function_name
}

output "lambda_function_invoke_arn" {
  description = "ARN para invocação da função Lambda"
  value       = aws_lambda_function.gerenciador_dns.invoke_arn
}

output "lambda_dynamodb_table_name" {
  description = "Nome da tabela DynamoDB"
  value       = aws_dynamodb_table.registros_dns.name
}

output "lambda_dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB"
  value       = aws_dynamodb_table.registros_dns.arn
} 