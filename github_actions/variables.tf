variable "project_name" {
  type = string
}

variable "github_username" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "frontend_bucket_arn" {
  type        = string
  description = "フロントエンドS3バケットのARN（frontend-deployロールの権限範囲）"
}

variable "s3_kms_key_arn" {
  type        = string
  description = "S3 KMSキーのARN（SSE-KMSバケットへのPut用）"
}

variable "cloudfront_distribution_arn" {
  type        = string
  description = "CloudFront DistributionのARN（invalidation用）"
}

variable "environment" {
  type        = string
  description = "Deploy target environment (dev/stg/prod). Scopes the OIDC sub to repo:...:environment:<env>."
}
