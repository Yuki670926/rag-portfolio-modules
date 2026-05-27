output "s3_kms_key_arn" {
  value       = aws_kms_key.s3.arn
  description = "S3用KMSキーのARN"
}

output "dynamodb_kms_key_arn" {
  value       = aws_kms_key.dynamodb.arn
  description = "DynamoDB用KMSキーのARN"
}

output "sqs_kms_key_arn" {
  value       = aws_kms_key.sqs.arn
  description = "SQS用KMSキーのARN"
}

output "cloudtrail_kms_key_arn" {
  value       = aws_kms_key.cloudtrail.arn
  description = "CloudTrail用KMSキーのARN"
}
