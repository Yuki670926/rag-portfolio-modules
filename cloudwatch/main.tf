terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# アラーム通知用SNSトピック（OpenSearch構成に依存しない独立トピック）
resource "aws_sns_topic" "alarm_notification" {
  name = "${var.project_name}-alarm-notification"
  tags = {
    Name = "${var.project_name}-alarm-notification"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm_notification.arn
  protocol  = "email"
  endpoint  = var.alert_email
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
  alarm_actions       = [aws_sns_topic.alarm_notification.arn]

  dimensions = {
    FunctionName = "${var.project_name}-ingest"
  }
}

# （opensearch-start/stop のアラームは削除済：対象 Lambda は eventbridge モジュールごと撤去。
#   NextGen の scale-to-zero により起動停止スケジューラ自体が不要化）

# AOSS の OCU 滞留アラーム：scale-to-zero が想定どおり効いているかの監視。
# OCU はログイン起点ウォーマー後しばらく >0 が正常だが、平均 >0 が 4 時間続くのは
# 「ゼロに戻っていない」シグナル（検知が $60 Budgets 消化後しかない穴を塞ぐ）。
# 次元の CollectionGroupId は collection 再作成で変わるため、root から
# Terraform グラフ経由（module.opensearch の output）で受け取り自動追従させる。
resource "aws_cloudwatch_metric_alarm" "aoss_ocu" {
  for_each = var.aoss_collection_group_id != "" ? toset(["SearchOCU", "IndexingOCU"]) : toset([])

  alarm_name          = "${var.project_name}-aoss-${lower(each.key)}-lingering"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 4
  metric_name         = each.key
  namespace           = "AWS/AOSS"
  period              = 3600
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching" # scale-to-zero 中はデータ無し＝正常
  alarm_description   = "AOSS の ${each.key} が 4 時間連続で 0 より大きい（scale-to-zero 不全の疑い）"
  alarm_actions       = [aws_sns_topic.alarm_notification.arn]

  dimensions = {
    ClientId            = var.account_id
    CollectionGroupId   = var.aoss_collection_group_id
    CollectionGroupName = var.aoss_collection_group_name
  }
}
