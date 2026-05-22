variable "project_name" {
  type = string
}

variable "environment" {
  type        = string
  description = "環境名（dev / stag / prod）"
}

variable "budget_limit" {
  type        = string
  description = "月額予算上限（USD）"
  default     = "100"
}