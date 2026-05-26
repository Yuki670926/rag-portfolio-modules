output "sns_topic_arn" {
  value       = aws_sns_topic.opensearch_notification.arn
  description = "SNS通知トピックARN"
}