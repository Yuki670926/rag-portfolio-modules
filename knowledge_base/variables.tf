variable "project_name" {
  type        = string
  description = "プロジェクト名（rp-{env} を含む）"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID（信頼ポリシーのSourceAccount限定用）"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン（信頼ポリシー・モデルARN用）"
}

variable "documents_bucket_arn" {
  type        = string
  description = "データソースとなるdocuments S3バケットのARN"
}

variable "vector_bucket_arn" {
  type        = string
  description = "S3 Vector BucketのARN（KB権限付与用）"
}

variable "vector_index_arn" {
  type        = string
  description = "S3 Vector IndexのARN（storage_configuration用）"
}

variable "kms_key_arn" {
  type        = string
  description = "復号/暗号化に使用するKMSキーのARN"
}

variable "dimension" {
  type        = number
  description = "埋め込みベクトルの次元数（Titan Text Embeddings V2 = 1024）"
  default     = 1024
}
