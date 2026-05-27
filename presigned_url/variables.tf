variable "project_name" {
  type = string
}

variable "documents_bucket_name" {
  type = string
}

# S3バケットARN（IAMポリシーで使用）
variable "documents_bucket_arn" {
  type        = string
  description = "ドキュメントS3バケットのARN"
}

variable "rest_api_id" {
  type = string
}

variable "root_resource_id" {
  type = string
}

variable "authorizer_id" {
  type = string
}

variable "execution_arn" {
  type = string
}

variable "lambda_authorizer_id" {
  type        = string
  description = "Lambda AuthorizerのID"
}
