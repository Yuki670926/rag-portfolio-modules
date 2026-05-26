resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-dlq-${var.queue_name_suffix}"
  message_retention_seconds = var.message_retention_seconds
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-dlq-${var.queue_name_suffix}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}