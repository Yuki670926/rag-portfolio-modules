output "knowledge_base_id" {
  value       = aws_bedrockagent_knowledge_base.main.id
  description = "Knowledge BaseのID（query LambdaのRetrieve呼び出しで使用）"
}

output "knowledge_base_arn" {
  value       = aws_bedrockagent_knowledge_base.main.arn
  description = "Knowledge BaseのARN"
}

output "data_source_id" {
  value       = aws_bedrockagent_data_source.main.data_source_id
  description = "データソースのID（ingest LambdaのStartIngestionJobで使用）"
}

output "kb_role_arn" {
  value       = aws_iam_role.kb.arn
  description = "KB用IAMロールのARN"
}
