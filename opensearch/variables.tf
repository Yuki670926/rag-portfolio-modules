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