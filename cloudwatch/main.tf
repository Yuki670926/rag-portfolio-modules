terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda エラー数"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-ingest"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-query"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-presigned-url"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda 実行時間"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-ingest"],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-query"],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-presigned-url"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway レイテンシ"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", "${var.project_name}-api"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway 4XXエラー"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", "${var.project_name}-api"]
          ]
        }
      }
    ]
  })
}

# ingest Lambda エラーアラーム
resource "aws_cloudwatch_metric_alarm" "ingest_errors" {
  alarm_name          = "${var.project_name}-ingest-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ingest Lambdaでエラーが発生しました"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = "${var.project_name}-ingest"
  }
}

# opensearch-start Lambda エラーアラーム
resource "aws_cloudwatch_metric_alarm" "opensearch_start_errors" {
  alarm_name          = "${var.project_name}-opensearch-start-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "opensearch-start Lambdaでエラーが発生しました"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = "${var.project_name}-opensearch-start"
  }
}

# opensearch-stop Lambda エラーアラーム
resource "aws_cloudwatch_metric_alarm" "opensearch_stop_errors" {
  alarm_name          = "${var.project_name}-opensearch-stop-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "opensearch-stop Lambdaでエラーが発生しました"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = "${var.project_name}-opensearch-stop"
  }
}