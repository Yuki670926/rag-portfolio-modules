variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "kms_key_arn" {
  type        = string
  description = "DynamoDB用KMSキーのARN"
}

variable "deletion_protection" {
  type        = bool
  description = "テーブルの削除保護（DeleteTable を API レベルで拒否。prod で true）。PITR は削除時に35日のシステムバックアップを残すが、削除自体を防ぐのはこの設定"
  default     = false
}