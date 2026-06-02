variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "environment" {
  type        = string
  description = "環境名（dev/stag/prod）"
}

variable "vector_store_endpoint" {
  type        = string
  description = "ベクトルストアのエンドポイント"
}

variable "vector_store_type" {
  type        = string
  description = "ベクトルストアの種類（opensearch時のみエンドポイントパラメータを作成）"
}
