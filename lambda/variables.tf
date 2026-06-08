variable "project_name" {
  type = string
}

variable "documents_bucket_arn" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "CognitoユーザープールID"
}

variable "cognito_client_id" {
  type        = string
  description = "CognitoクライアントID"
}

variable "conversations_table_name" {
  type        = string
  description = "会話履歴テーブル名"
}

variable "sessions_table_name" {
  type        = string
  description = "セッション管理テーブル名"
}

variable "memory_size" {
  type        = number
  description = "Lambdaメモリサイズ（MB）"
  default     = 512
}

variable "vector_store_type" {
  type        = string
  description = "ベクトルストアの種類（opensearch or s3_vectors）"
  default     = "opensearch"
}

variable "environment" {
  type        = string
  description = "環境名（dev/stag/prod）"
}

variable "ingest_dlq_arn" {
  type        = string
  description = "ingest Lambda用DLQのARN"
}

variable "subnet_ids" {
  type        = list(string)
  description = "LambdaをデプロイするサブネットIDのリスト"
}

variable "lambda_security_group_id" {
  type        = string
  description = "Lambda用セキュリティグループID"
}

variable "knowledge_base_id" {
  type        = string
  description = "Bedrock Knowledge BaseのID（s3_vectors時のみ。opensearch時は空文字）"
  default     = ""
}

variable "data_source_id" {
  type        = string
  description = "Bedrock KB データソースのID（ingestのStartIngestionJob用）"
  default     = ""
}

variable "knowledge_base_arn" {
  type        = string
  description = "Bedrock Knowledge BaseのARN（KB操作のIAM権限を絞るため）"
  default     = "*"
}

variable "enable_private_networking" {
  type        = bool
  description = "LambdaをVPC内に配置するか（プライベートネットワーキング有効化時。VPCエンドポイント経由でbedrock等へプライベート通信）"
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "DynamoDB等の暗号化に使うKMSキーのARN（query LambdaがKMS暗号化テーブルを読み書きするため）"
  default     = ""
}

variable "pdf_indexes_table_name" {
  type        = string
  description = "PDF索引化の準備完了フラグを記録する DynamoDB テーブル名（ingest が PutItem）"
  default     = ""
}

variable "pdf_indexes_table_arn" {
  type        = string
  description = "pdf_indexes テーブルの ARN（ingest ロールの dynamodb:PutItem 用）"
  default     = ""
}
