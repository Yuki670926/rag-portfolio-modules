variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID"
}

variable "create_aoss_key" {
  type        = bool
  description = "OpenSearch Serverless 用 CMK を作成するか（vector_store_type=opensearch のときのみ true）"
  default     = false
}

variable "create_cloudtrail_key" {
  type        = bool
  description = "CloudTrail 用 CMK を作成するか。per-env trail を組織 trail に一本化したため既定 false（移行期間中のみ root から true を渡す）"
  default     = true
}

variable "aoss_grant_principal_arns" {
  type        = list(string)
  description = "aoss 用 CMK に kms:CreateGrant を明示許可するプリンシパル（apply ロール等）。grant 経路が AdministratorAccess に暗黙依存する状態を解消し、将来の CI 最小権限化に備える"
  default     = []
}

variable "s3_key_deletion_window_in_days" {
  type        = number
  description = "s3 用 CMK の削除待機日数（prod=30）。s3 鍵は正本（documents・DynamoDB ほか）の暗号化を一手に担い、喪失＝全データ実質消失のため取消猶予を長く取る。aoss 鍵は crypto-shredding（鍵無効化による消去）の意図的設計のため対象外"
  default     = 7
}
