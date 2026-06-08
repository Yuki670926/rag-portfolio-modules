# ------------------------------------------------------------
# 共通ローカル値
#   Lambda Powertools Layer ARN を3関数(ingest/query/authorizer)で一元管理する。
#   命名規則: AWSLambdaPowertoolsPythonV3-{python_version}-{arch}:{version}
#   V3からアーキテクチャsuffix(-x86_64)が必須。:19 はライブラリ v3.16.0 に対応。
# ------------------------------------------------------------
locals {
  powertools_layer_arn = "arn:aws:lambda:ap-northeast-1:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-x86_64:19"
}

data "archive_file" "ingest" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/ingest"
  output_path = "${path.root}/../lambda/ingest.zip"
}

data "archive_file" "query" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/query"
  output_path = "${path.root}/../lambda/query.zip"
}

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/authorizer"
  output_path = "${path.root}/../lambda/authorizer.zip"
}

# ingest Lambda IAMロール
resource "aws_iam_role" "ingest" {
  name = "${var.project_name}-lambda-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# ingest Lambda IAMポリシー
resource "aws_iam_role_policy" "ingest" {
  name = "${var.project_name}-lambda-ingest-policy"
  role = aws_iam_role.ingest.id

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
        Action   = ["s3:GetObject"]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob"]
        Resource = var.knowledge_base_arn
      },
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/rp/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = var.ingest_dlq_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        # documents バケットは SSE-KMS（PDF の GetObject 復号に kms:Decrypt）。
        # pdf_indexes(DynamoDB) も同じ KMS 鍵で暗号化されており、PutItem には
        # kms:GenerateDataKey も要る。両用途を1文で許可。
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
      {
        # 索引化完了フラグの記録（フロントの準備完了 polling 用）。pdf_indexes へ PutItem のみ。
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.pdf_indexes_table_arn
      }
    ]
    }
  )
}

# query Lambda IAMロール
resource "aws_iam_role" "query" {
  name = "${var.project_name}-lambda-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# query Lambda IAMポリシー
resource "aws_iam_role_policy" "query" {
  name = "${var.project_name}-lambda-query-policy"
  role = aws_iam_role.query.id

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
        Action   = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:Retrieve"]
        Resource = var.knowledge_base_arn
      },
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:Query", "dynamodb:PutItem"]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.conversations_table_name}",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.sessions_table_name}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/rp/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# authorizer Lambda IAMロール
resource "aws_iam_role" "authorizer" {
  name = "${var.project_name}-lambda-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# authorizer Lambda IAMポリシー
resource "aws_iam_role_policy" "authorizer" {
  name = "${var.project_name}-lambda-authorizer-policy"
  role = aws_iam_role.authorizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ingest/query 共通 Layer (boto3新版 + opensearchpy + requests_aws4auth + pypdf)
data "archive_file" "ingest_query_layer" {
  type        = "zip"
  source_dir  = "${path.root}/../layers/ingest-query/build"
  output_path = "${path.root}/../layers/ingest-query/ingest_query_layer.zip"
}

resource "aws_lambda_layer_version" "ingest_query" {
  layer_name          = "${var.project_name}-ingest-query-deps"
  filename            = data.archive_file.ingest_query_layer.output_path
  source_code_hash    = data.archive_file.ingest_query_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# ingest Lambda
resource "aws_lambda_function" "ingest" {
  filename         = data.archive_file.ingest.output_path
  function_name    = "${var.project_name}-ingest"
  role             = aws_iam_role.ingest.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = var.memory_size
  source_code_hash = data.archive_file.ingest.output_base64sha256
  layers           = [local.powertools_layer_arn, aws_lambda_layer_version.ingest_query.arn]

  environment {
    variables = {
      VECTOR_STORE_TYPE            = var.vector_store_type
      SSM_ENDPOINT_PARAM           = "/rp/${var.environment}/vector-store/endpoint"
      POWERTOOLS_SERVICE_NAME      = "${var.project_name}-ingest"
      POWERTOOLS_LOG_LEVEL         = "INFO"
      POWERTOOLS_METRICS_NAMESPACE = "RagPortfolio"
      KNOWLEDGE_BASE_ID            = var.knowledge_base_id
      DATA_SOURCE_ID               = var.data_source_id
      PDF_INDEXES_TABLE            = var.pdf_indexes_table_name
    }

  }

  tags = {
    Name = "${var.project_name}-ingest"
  }

  dead_letter_config {
    target_arn = var.ingest_dlq_arn
  }

  dynamic "vpc_config" {
    for_each = var.enable_private_networking ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.lambda_security_group_id]
    }
  }

  tracing_config {
    mode = "Active"
  }

}

# query Lambda
resource "aws_lambda_function" "query" {
  filename         = data.archive_file.query.output_path
  function_name    = "${var.project_name}-query"
  role             = aws_iam_role.query.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = var.memory_size
  source_code_hash = data.archive_file.query.output_base64sha256
  layers           = [local.powertools_layer_arn, aws_lambda_layer_version.ingest_query.arn]

  environment {
    variables = {
      VECTOR_STORE_TYPE            = var.vector_store_type
      SSM_ENDPOINT_PARAM           = "/rp/${var.environment}/vector-store/endpoint"
      CONVERSATIONS_TABLE          = var.conversations_table_name
      SESSIONS_TABLE               = var.sessions_table_name
      POWERTOOLS_SERVICE_NAME      = "${var.project_name}-query"
      POWERTOOLS_LOG_LEVEL         = "INFO"
      POWERTOOLS_METRICS_NAMESPACE = "RagPortfolio"
      KNOWLEDGE_BASE_ID            = var.knowledge_base_id
    }
  }

  tags = {
    Name = "${var.project_name}-query"
  }

  dynamic "vpc_config" {
    for_each = var.enable_private_networking ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.lambda_security_group_id]
    }
  }

  tracing_config {
    mode = "Active"
  }

}

# authorizer Layer (python-jose + cryptography)
# Docker(Lambda公式イメージ)でビルドした Lambda互換バイナリを Layer 化。
# build/python/ 構造を保つため source_dir は build/ を指す。
data "archive_file" "authorizer_layer" {
  type        = "zip"
  source_dir  = "${path.root}/../layers/authorizer/build"
  output_path = "${path.root}/../layers/authorizer/authorizer_layer.zip"
}

resource "aws_lambda_layer_version" "authorizer" {
  layer_name          = "${var.project_name}-authorizer-deps"
  filename            = data.archive_file.authorizer_layer.output_path
  source_code_hash    = data.archive_file.authorizer_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# authorizer Lambda
resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.authorizer.output_path
  function_name    = "${var.project_name}-authorizer"
  role             = aws_iam_role.authorizer.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  layers           = [local.powertools_layer_arn, aws_lambda_layer_version.authorizer.arn]

  environment {
    variables = {
      REGION                       = var.aws_region
      USER_POOL_ID                 = var.cognito_user_pool_id
      APP_CLIENT_ID                = var.cognito_client_id
      ALLOWED_GROUP                = "Admin"
      POWERTOOLS_SERVICE_NAME      = "${var.project_name}-authorizer"
      POWERTOOLS_LOG_LEVEL         = "INFO"
      POWERTOOLS_METRICS_NAMESPACE = "RagPortfolio"
    }
  }

  tags = {
    Name = "${var.project_name}-authorizer"
  }

}

# S3からLambdaを呼び出す権限
resource "aws_lambda_permission" "s3_ingest" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.documents_bucket_arn
}

# ingest Lambdaリトライ設定
resource "aws_lambda_function_event_invoke_config" "ingest" {
  function_name          = aws_lambda_function.ingest.function_name
  maximum_retry_attempts = 2
}
