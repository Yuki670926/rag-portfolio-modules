variable "project_name" {
  type = string
}

variable "documents_bucket_arn" {
  type = string
}

variable "opensearch_endpoint" {
  type    = string
  default = ""
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "CognitoユーザープールID"
}

variable "cognito_client_id" {
  type        = string
  description = "CognitoクライアントID"
}