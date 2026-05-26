output "dlq_arn" {
  value       = aws_sqs_queue.dlq.arn
  description = "DLQのARN"
}