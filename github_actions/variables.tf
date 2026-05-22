variable "project_name" {
  type = string
}

variable "github_username" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "frontend_bucket_name" {
  type        = string
  description = "フロントエンドS3バケット名"
}

variable "cf_distribution_id" {
  type        = string
  description = "CloudFront Distribution ID"
}
