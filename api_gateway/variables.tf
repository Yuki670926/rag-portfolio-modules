variable "project_name" {
  type = string
}

variable "cognito_user_pool_arn" {
  type = string
}

variable "query_lambda_arn" {
  type = string
}

variable "query_lambda_invoke_arn" {
  type = string
}

variable "cloudfront_domain" {
  type        = string
  description = "CloudFrontのドメイン名"
}

variable "cognito_user_pool_id" {
  type        = string
  description = "CognitoユーザープールID（Lambda Authorizer用）"
}

variable "cognito_client_id" {
  type        = string
  description = "CognitoクライアントID（Lambda Authorizer用）"
}

variable "authorizer_lambda_invoke_arn" {
  type        = string
  description = "Lambda AuthorizerのInvoke ARN"
}

variable "authorizer_lambda_arn" {
  type        = string
  description = "Lambda AuthorizerのARN"
}

variable "stage_name" {
  type        = string
  description = "API Gatewayのステージ名"
  default     = "prod"
}

