data "archive_file" "presigned_url" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/presigned_url"
  output_path = "${path.root}/../lambda/presigned_url.zip"
}

# presigned-url Lambda IAMロール
resource "aws_iam_role" "presigned_url" {
  name = "${var.project_name}-presigned-url-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# presigned-url Lambda IAMポリシー
resource "aws_iam_role_policy" "presigned_url" {
  name = "${var.project_name}-presigned-url-lambda-policy"
  role = aws_iam_role.presigned_url.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        # SSE-KMS の documents へ PUT する際、S3 が暗号化のため KMS を呼ぶ。
        # presigned URL の署名者（本ロール）の権限で評価されるため、対象キーへの権限が必要。
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arn
      },
      {
        # GET /status：索引化の準備完了を pdf_indexes から読む（GetItem）。
        # DeleteItem：POST /upload 成功時に同名 PDF の旧 readiness フラグを掃除し、
        # 再アップロード直後の polling が前回の ready を拾う偽陽性を防ぐ（冪等）。
        # DynamoDB は同一 KMS 鍵で暗号化されており、復号は上の kms:Decrypt で賄える。
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
        Resource = var.pdf_indexes_table_arn
      },
      {
        # GET /status（s3_vectors時）：最新の KB 取り込みジョブ状態を読む（read-only）。
        # KB ID は count で動的（opensearch時は不在）のため knowledge-base/* に限定。
        Effect   = "Allow"
        Action   = ["bedrock:ListIngestionJobs", "bedrock:GetIngestionJob"]
        Resource = "arn:aws:bedrock:*:*:knowledge-base/*"
      }
    ]
  })
}

resource "aws_lambda_function" "presigned_url" {
  filename         = data.archive_file.presigned_url.output_path
  function_name    = "${var.project_name}-presigned-url"
  role             = aws_iam_role.presigned_url.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  timeout          = 30
  source_code_hash = data.archive_file.presigned_url.output_base64sha256

  environment {
    variables = {
      DOCUMENTS_BUCKET  = var.documents_bucket_name
      PDF_INDEXES_TABLE = var.pdf_indexes_table_name
      VECTOR_STORE_TYPE = var.vector_store_type
      KNOWLEDGE_BASE_ID = var.knowledge_base_id
      DATA_SOURCE_ID    = var.data_source_id
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.presigned_url.name
  }

  tags = {
    Name = "${var.project_name}-presigned-url"
  }
}

# ログ保持 30 日（既定の自動作成ロググループは保持無期限のため、IaC 管理のグループへ出力を切替）
resource "aws_cloudwatch_log_group" "presigned_url" {
  name              = "/lambda/${var.project_name}-presigned-url"
  retention_in_days = 30
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = var.rest_api_id
  parent_id   = var.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = var.lambda_authorizer_id
}

resource "aws_api_gateway_integration" "upload_lambda" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presigned_url.invoke_arn
}

resource "aws_api_gateway_method" "upload_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
  }
  depends_on = [aws_api_gateway_integration.upload_options]
}

# ---- GET /status?pdf=<filename>：索引化の準備完了照会（フロントの polling 用） ----
resource "aws_api_gateway_resource" "status" {
  rest_api_id = var.rest_api_id
  parent_id   = var.root_resource_id
  path_part   = "status"
}

resource "aws_api_gateway_method" "status_get" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.status.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = var.lambda_authorizer_id
}

resource "aws_api_gateway_integration" "status_lambda" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.status.id
  http_method             = aws_api_gateway_method.status_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presigned_url.invoke_arn
}

resource "aws_api_gateway_method" "status_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.status.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "status_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "status_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "status_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.status.id
  http_method = aws_api_gateway_method.status_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
  }
  depends_on = [aws_api_gateway_integration.status_options]
}

resource "aws_lambda_permission" "api_gateway_presigned" {
  statement_id  = "AllowAPIGatewayInvokePresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.execution_arn}/*/*"
}
