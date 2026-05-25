output "vector_store_endpoint_param_name" {
  value       = aws_ssm_parameter.vector_store_endpoint.name
  description = "SSMパラメータ名"
}