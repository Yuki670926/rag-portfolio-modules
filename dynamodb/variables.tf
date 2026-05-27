variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "kms_key_arn" {
  type        = string
  description = "DynamoDB用KMSキーのARN"
}