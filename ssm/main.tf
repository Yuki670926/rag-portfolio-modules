resource "aws_ssm_parameter" "vector_store_endpoint" {
  count       = contains(["opensearch", "dual"], var.vector_store_type) ? 1 : 0
  name        = "/rp/${var.environment}/vector-store/endpoint"
  type        = "SecureString"
  value       = var.vector_store_endpoint
  description = "ベクトルストアのエンドポイント"

  tags = {
    Name = "${var.project_name}-vector-store-endpoint"
  }
}
