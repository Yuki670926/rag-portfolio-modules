variable "project_name" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "alert_email" {
  type        = string
  description = "アラーム通知先メールアドレス"
}
