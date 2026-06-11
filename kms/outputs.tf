output "s3_kms_key_arn" {
  value       = aws_kms_key.s3.arn
  description = "S3用KMSキーのARN"
}

output "sqs_kms_key_arn" {
  value       = aws_kms_key.sqs.arn
  description = "SQS用KMSキーのARN"
}

output "cloudtrail_kms_key_arn" {
  value       = try(aws_kms_key.cloudtrail[0].arn, "")
  description = "CloudTrail用KMSキーのARN（未作成時は空）"
}

output "aoss_kms_key_arn" {
  value       = try(aws_kms_key.aoss[0].arn, "")
  description = "aoss 用 CMK の ARN（未作成時は空）"
}
