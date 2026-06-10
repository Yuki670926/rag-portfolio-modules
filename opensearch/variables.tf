variable "project_name" {
  type = string
}

# ingest Lambda IAMロールARN
variable "ingest_lambda_role_arn" {
  type        = string
  description = "ingest Lambda IAMロールのARN"
}

# query Lambda IAMロールARN
variable "query_lambda_role_arn" {
  type        = string
  description = "query Lambda IAMロールのARN"
}

variable "enable_private_networking" {
  type        = bool
  description = "true でネットワークポリシーを公開→aoss VPC EP 限定に切替（VPC 隔離）"
  default     = false
}

variable "aoss_vpc_endpoint_id" {
  type        = string
  description = "aoss 専用 VPC エンドポイントID（enable_private_networking=true 時に SourceVPCEs へ）"
  default     = ""
}

variable "kms_key_arn" {
  type        = string
  description = "collection 暗号化用 CMK の ARN（空なら AWS 所有キー）"
  default     = ""
}
