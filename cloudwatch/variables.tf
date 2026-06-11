variable "project_name" {
  type = string
}

variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "alert_email" {
  type        = string
  description = "アラーム通知先メールアドレス"
}

variable "account_id" {
  type        = string
  description = "AWSアカウントID（AOSS OCU メトリクスの ClientId 次元）"
  default     = ""
}

variable "aoss_collection_group_id" {
  type        = string
  description = "AOSS NextGen コレクショングループ ID（OCU アラームの次元。空なら OCU アラームを作らない。再作成で変わるため Terraform グラフ経由で受け取る）"
  default     = ""
}

variable "aoss_collection_group_name" {
  type        = string
  description = "AOSS NextGen コレクショングループ名（OCU アラームの次元）"
  default     = ""
}
