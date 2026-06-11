variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "kms_key_arn" {
  type        = string
  description = "CloudTrailログ暗号化用KMSキーのARN"
}

variable "log_retention_days" {
  type        = number
  description = "CloudTrailログの保持期間（日）"
  default     = 365
}

variable "force_destroy" {
  type        = bool
  description = "ログバケットの強制削除を許可（組織 trail への一本化＝モジュール撤去の移行用。通常 false）"
  default     = false
}
