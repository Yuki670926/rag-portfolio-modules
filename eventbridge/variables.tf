variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名（dev/stag/prod）"
}

variable "collection_name" {
  type        = string
  description = "OpenSearch コレクション名"
}

variable "ssm_endpoint_param" {
  type        = string
  description = "SSMパラメータ名"
}

variable "pdf_indexes_table_name" {
  type        = string
  description = "PDFインデックス状態テーブル名"
}

variable "ingest_lambda_arn" {
  type        = string
  description = "ingest LambdaのARN"
}

variable "ingest_lambda_name" {
  type        = string
  description = "ingest Lambda関数名"
}

variable "documents_bucket_name" {
  type        = string
  description = "PDFが保存されているS3バケット名"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS通知トピックARN"
}

variable "lambda_role_arn" {
  type        = string
  description = "LambdaのIAMロールARN"
}

variable "alert_email" {
  type        = string
  description = "SNS通知先メールアドレス"
}

variable "opensearch_start_dlq_arn" {
  type        = string
  description = "opensearch-start Lambda用DLQのARN"
}

variable "opensearch_stop_dlq_arn" {
  type        = string
  description = "opensearch-stop Lambda用DLQのARN"
}