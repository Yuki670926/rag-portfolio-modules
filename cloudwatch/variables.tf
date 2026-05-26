variable "project_name" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNSトピックARN（アラート通知用）"
}