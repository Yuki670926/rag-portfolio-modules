output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_route_table_id" {
  value       = aws_route_table.private.id
  description = "プライベートサブネット用ルートテーブルID"
}

output "vpc_endpoint_security_group_id" {
  value       = aws_security_group.vpc_endpoint.id
  description = "VPCエンドポイント用セキュリティグループID"
}

output "lambda_security_group_id" {
  value       = aws_security_group.lambda.id
  description = "Lambda用セキュリティグループID"
}

output "aoss_vpc_endpoint_id" {
  value       = try(aws_opensearchserverless_vpc_endpoint.aoss[0].id, "")
  description = "aoss 専用 VPC エンドポイントID（opensearch network policy の SourceVPCEs 用。非VPC時は空）"
}