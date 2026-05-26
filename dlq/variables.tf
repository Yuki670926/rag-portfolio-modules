variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名（dev/stag/prod）"
}

variable "queue_name_suffix" {
  type        = string
  description = "キューの用途を示すサフィックス（ingest, opensearch-start, opensearch-stop）"
}

variable "message_retention_seconds" {
  type        = number
  description = "メッセージの保持期間（秒）"
  default     = 1209600  # 14日間
}