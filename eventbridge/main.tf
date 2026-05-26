# SNSトピック
resource "aws_sns_topic" "opensearch_notification" {
  name = "${var.project_name}-opensearch-notification"
  tags = {
    Name = "${var.project_name}-opensearch-notification"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.opensearch_notification.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 起動Lambda
resource "aws_lambda_function" "opensearch_start" {
  filename         = data.archive_file.opensearch_start.output_path
  function_name    = "${var.project_name}-opensearch-start"
  role             = var.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 600
  memory_size      = 512
  source_code_hash = data.archive_file.opensearch_start.output_base64sha256

  environment {
    variables = {
      COLLECTION_NAME      = var.collection_name
      SSM_ENDPOINT_PARAM   = var.ssm_endpoint_param
      PDF_INDEXES_TABLE    = var.pdf_indexes_table_name
      INGEST_LAMBDA_NAME   = var.ingest_lambda_name
      SNS_TOPIC_ARN        = aws_sns_topic.opensearch_notification.arn
    }
  }

  tags = {
    Name = "${var.project_name}-opensearch-start"
  }

  dead_letter_config {
    target_arn = var.opensearch_start_dlq_arn
  }
}

data "archive_file" "opensearch_start" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/opensearch_start"
  output_path = "${path.root}/../lambda/opensearch_start.zip"
}

# 停止Lambda
resource "aws_lambda_function" "opensearch_stop" {
  filename         = data.archive_file.opensearch_stop.output_path
  function_name    = "${var.project_name}-opensearch-stop"
  role             = var.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 512
  source_code_hash = data.archive_file.opensearch_stop.output_base64sha256

  environment {
    variables = {
      COLLECTION_NAME = var.collection_name
      SNS_TOPIC_ARN   = aws_sns_topic.opensearch_notification.arn
    }
  }

  tags = {
    Name = "${var.project_name}-opensearch-stop"
  }

  dead_letter_config {
    target_arn = var.opensearch_stop_dlq_arn
  }
}

data "archive_file" "opensearch_stop" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/opensearch_stop"
  output_path = "${path.root}/../lambda/opensearch_stop.zip"
}

# EventBridgeスケジュール（起動: 9:00 JST）
resource "aws_cloudwatch_event_rule" "opensearch_start_morning" {
  name                = "${var.project_name}-opensearch-start-morning"
  description         = "OpenSearch起動（平日9:00 JST）"
  schedule_expression = "cron(0 0 ? * MON-FRI *)"
  tags = {
    Name = "${var.project_name}-opensearch-start-morning"
  }
}

resource "aws_cloudwatch_event_target" "opensearch_start_morning" {
  rule      = aws_cloudwatch_event_rule.opensearch_start_morning.name
  target_id = "opensearch-start-morning"
  arn       = aws_lambda_function.opensearch_start.arn
}

resource "aws_lambda_permission" "opensearch_start_morning" {
  statement_id  = "AllowEventBridgeStartMorning"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opensearch_start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.opensearch_start_morning.arn
}

# EventBridgeスケジュール（停止: 12:00 JST）
resource "aws_cloudwatch_event_rule" "opensearch_stop_lunch" {
  name                = "${var.project_name}-opensearch-stop-lunch"
  description         = "OpenSearch停止（平日12:00 JST）"
  schedule_expression = "cron(0 3 ? * MON-FRI *)"
  tags = {
    Name = "${var.project_name}-opensearch-stop-lunch"
  }
}

resource "aws_cloudwatch_event_target" "opensearch_stop_lunch" {
  rule      = aws_cloudwatch_event_rule.opensearch_stop_lunch.name
  target_id = "opensearch-stop-lunch"
  arn       = aws_lambda_function.opensearch_stop.arn
}

resource "aws_lambda_permission" "opensearch_stop_lunch" {
  statement_id  = "AllowEventBridgeStopLunch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opensearch_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.opensearch_stop_lunch.arn
}

# EventBridgeスケジュール（起動: 12:55 JST）
resource "aws_cloudwatch_event_rule" "opensearch_start_afternoon" {
  name                = "${var.project_name}-opensearch-start-afternoon"
  description         = "OpenSearch起動（平日12:55 JST）"
  schedule_expression = "cron(55 3 ? * MON-FRI *)"
  tags = {
    Name = "${var.project_name}-opensearch-start-afternoon"
  }
}

resource "aws_cloudwatch_event_target" "opensearch_start_afternoon" {
  rule      = aws_cloudwatch_event_rule.opensearch_start_afternoon.name
  target_id = "opensearch-start-afternoon"
  arn       = aws_lambda_function.opensearch_start.arn
}

resource "aws_lambda_permission" "opensearch_start_afternoon" {
  statement_id  = "AllowEventBridgeStartAfternoon"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opensearch_start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.opensearch_start_afternoon.arn
}

# EventBridgeスケジュール（停止: 18:00 JST）
resource "aws_cloudwatch_event_rule" "opensearch_stop_evening" {
  name                = "${var.project_name}-opensearch-stop-evening"
  description         = "OpenSearch停止（平日18:00 JST）"
  schedule_expression = "cron(0 9 ? * MON-FRI *)"
  tags = {
    Name = "${var.project_name}-opensearch-stop-evening"
  }
}

resource "aws_cloudwatch_event_target" "opensearch_stop_evening" {
  rule      = aws_cloudwatch_event_rule.opensearch_stop_evening.name
  target_id = "opensearch-stop-evening"
  arn       = aws_lambda_function.opensearch_stop.arn
}

resource "aws_lambda_permission" "opensearch_stop_evening" {
  statement_id  = "AllowEventBridgeStopEvening"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opensearch_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.opensearch_stop_evening.arn
}

# opensearch-start Lambdaリトライ設定
resource "aws_lambda_function_event_invoke_config" "opensearch_start" {
  function_name          = aws_lambda_function.opensearch_start.function_name
  maximum_retry_attempts = 2
}

# opensearch-stop Lambdaリトライ設定
resource "aws_lambda_function_event_invoke_config" "opensearch_stop" {
  function_name          = aws_lambda_function.opensearch_stop.function_name
  maximum_retry_attempts = 2
}