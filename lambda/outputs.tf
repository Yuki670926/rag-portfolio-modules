output "ingest_lambda_arn" {
  value       = aws_lambda_function.ingest.arn
  description = "ingest LambdaのARN"
}

output "query_lambda_arn" {
  value       = aws_lambda_function.query.arn
  description = "query LambdaのARN"
}

output "query_lambda_invoke_arn" {
  value       = aws_lambda_function.query.invoke_arn
  description = "query LambdaのInvoke ARN"
}

output "authorizer_lambda_arn" {
  value       = aws_lambda_function.authorizer.arn
  description = "authorizer LambdaのARN"
}

output "authorizer_lambda_invoke_arn" {
  value       = aws_lambda_function.authorizer.invoke_arn
  description = "authorizer LambdaのInvoke ARN"
}

output "ingest_lambda_role_arn" {
  value       = aws_iam_role.ingest.arn
  description = "ingest Lambda IAMロールのARN"
}

output "query_lambda_role_arn" {
  value       = aws_iam_role.query.arn
  description = "query Lambda IAMロールのARN"
}