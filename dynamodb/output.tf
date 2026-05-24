output "conversations_table_name" {
  value       = aws_dynamodb_table.conversations.name
  description = "会話履歴テーブル名"
}

output "sessions_table_name" {
  value       = aws_dynamodb_table.sessions.name
  description = "セッション管理テーブル名"
}

output "pdf_indexes_table_name" {
  value       = aws_dynamodb_table.pdf_indexes.name
  description = "PDFインデックス状態テーブル名"
}