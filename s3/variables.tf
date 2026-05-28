variable "project_name" {
  type = string
}

variable "account_id" {
  type = string
}

variable "ingest_lambda_arn" {
  type    = string
  default = ""
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFrontドメイン名"
}

variable "kms_key_arn" {
  type        = string
  description = "S3用KMSキーのARN"
}

variable "api_url" {
  type        = string
  description = "API GatewayのエンドポイントURL"
}

variable "user_pool_id" {
  type        = string
  description = "CognitoユーザープールID"
}

variable "client_id" {
  type        = string
  description = "CognitoクライアントID"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}
