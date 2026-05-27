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
