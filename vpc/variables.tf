variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "enable_private_networking" {
  type        = bool
  description = "プライベートネットワーキングを有効化する（LambdaのVPC配置＋VPCエンドポイント経由のプライベート通信）。層3の経路隔離。"
  default     = false
}

variable "aoss_endpoint_enabled" {
  type        = bool
  description = "aoss-data VPC EP を作成するか。OpenSearch を使う場合のみ true（s3_vectors では不要な固定費になるため作らない）"
  default     = true
}
