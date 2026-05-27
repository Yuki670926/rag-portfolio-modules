variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID"
}