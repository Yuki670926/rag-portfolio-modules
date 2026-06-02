output "vector_store_endpoint_param_name" {
  value       = try(aws_ssm_parameter.vector_store_endpoint[0].name, "")
  description = "SSMパラメータ名"
}
