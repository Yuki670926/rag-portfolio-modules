variable "project_name" {
  type = string
}

variable "environment" {
  type        = string
  description = "環境名（dev / stag / prod）"
}

variable "admin_email" {
  type        = string
  description = "管理者のメールアドレス"
  default     = "test@example.com"
}
