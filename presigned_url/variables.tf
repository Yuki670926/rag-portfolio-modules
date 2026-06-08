variable "project_name" {
  type = string
}

variable "documents_bucket_name" {
  type = string
}

# S3バケットARN（IAMポリシーで使用）
variable "documents_bucket_arn" {
  type        = string
  description = "ドキュメントS3バケットのARN"
}

variable "rest_api_id" {
  type = string
}

variable "root_resource_id" {
  type = string
}

variable "authorizer_id" {
  type = string
}

variable "execution_arn" {
  type = string
}

variable "lambda_authorizer_id" {
  type        = string
  description = "Lambda AuthorizerのID"
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFrontのドメイン名"
}

# S3用KMSキーARN（SSE-KMSのdocumentsへPUTする際、暗号化のためにkms:GenerateDataKeyが要る）
variable "kms_key_arn" {
  type        = string
  description = "S3用KMSキーのARN（SSE-KMS PUTの暗号化に必要）"
}

variable "pdf_indexes_table_name" {
  type        = string
  description = "GET /status が読む pdf_indexes テーブル名"
  default     = ""
}

variable "pdf_indexes_table_arn" {
  type        = string
  description = "pdf_indexes テーブルの ARN（dynamodb:GetItem 用）"
  default     = ""
}
