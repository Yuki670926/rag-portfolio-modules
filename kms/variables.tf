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

variable "create_aoss_key" {
  type        = bool
  description = "OpenSearch Serverless 用 CMK を作成するか（vector_store_type=opensearch のときのみ true）"
  default     = false
}
