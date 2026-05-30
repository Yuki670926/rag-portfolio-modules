output "vector_bucket_arn" {
  value       = aws_s3vectors_vector_bucket.main.vector_bucket_arn
  description = "S3 Vector BucketのARN"
}

output "vector_bucket_name" {
  value       = aws_s3vectors_vector_bucket.main.vector_bucket_name
  description = "S3 Vector Bucketの名前"
}

output "vector_index_arn" {
  value       = aws_s3vectors_index.main.arn
  description = "S3 Vector IndexのARN（Bedrock KBのstorage_configurationで使用）"
}
