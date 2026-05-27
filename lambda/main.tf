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
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["aoss:APIAccessAll"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/rp/*"
      },
      {
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = var.ingest_dlq_arn
      }
    ]
  })
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
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["aoss:APIAccessAll"]
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
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/rp/*"
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
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
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

  environment {
  variables = {
    VECTOR_STORE_TYPE  = var.vector_store_type
    SSM_ENDPOINT_PARAM = "/rp/${var.environment}/vector-store/endpoint"
  }
}

  tags = {
    Name = "${var.project_name}-ingest"
  }

  dead_letter_config {
    target_arn = var.ingest_dlq_arn
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

  environment {
  variables = {
    VECTOR_STORE_TYPE    = var.vector_store_type
    SSM_ENDPOINT_PARAM   = "/rp/${var.environment}/vector-store/endpoint"
    CONVERSATIONS_TABLE  = var.conversations_table_name
    SESSIONS_TABLE       = var.sessions_table_name
  }
}

  tags = {
    Name = "${var.project_name}-query"
  }
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

  environment {
    variables = {
      REGION        = var.aws_region
      USER_POOL_ID  = var.cognito_user_pool_id
      APP_CLIENT_ID = var.cognito_client_id
      ALLOWED_GROUP = "Admin"
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