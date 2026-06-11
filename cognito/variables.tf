variable "project_name" {
  type = string
}

variable "environment" {
  type        = string
  description = "環境名（dev / stag / prod）"
}

variable "admin_email" {
  type        = string
  description = "管理者のメールアドレス"
  default     = "test@example.com"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン（postauth ウォーマーが query Lambda の ARN を構築するのに使用）"
  default     = "ap-northeast-1"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID（postauth ウォーマーの IAM Resource ARN 構築に使用）"
}

variable "deletion_protection" {
  type        = bool
  description = "User Pool の削除保護（prod で true）。登録ユーザーは再生成不能のため、置換を要求する apply を明示エラーで止める"
  default     = false
}
