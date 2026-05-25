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