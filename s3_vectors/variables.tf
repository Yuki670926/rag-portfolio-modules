variable "project_name" {
  type        = string
  description = "プロジェクト名（rp-{env} を含む）"
}

variable "kms_key_arn" {
  type        = string
  description = "S3 Vectors保存時暗号化用KMSキーのARN"
}

variable "dimension" {
  type        = number
  description = "ベクトルの次元数（Titan Text Embeddings V2 = 1024）"
  default     = 1024
}

variable "distance_metric" {
  type        = string
  description = "類似度計算の距離尺度（cosine または euclidean）"
  default     = "cosine"
}

variable "force_destroy" {
  type        = bool
  description = "破棄時にバケット内の全index/vectorごと削除するか"
  default     = false
}
