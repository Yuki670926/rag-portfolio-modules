terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # 削除保護（prod のみ ACTIVE）：schema 変更等で置換（replace）が要求された場合に
  # apply を明示エラーで停止し、登録ユーザーの不可逆な消失を防ぐ
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  # ログイン成功時に warmer を非同期起動するトリガ（cold-start 対策 D）。
  # postauth Lambda が query Lambda を {"warmup":true} で Event 起動し OpenSearch を暖機する。
  lambda_config {
    post_authentication = aws_lambda_function.postauth.arn
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  # セッション長を明示（セキュリティ：一定時間で再認証を要求）。フロントは idToken を使い
  # 自動更新しないため、実質セッション長 = id_token_validity(60分)。期限切れはフロントが 401 を
  # 検知して再ログインへ誘導（#2a）。再ログインのたびに Post-Auth ウォーマーが collection を暖機。
  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 30
  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_group" "admin" {
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Admin group"
}

resource "aws_cognito_user_group" "user" {
  name         = "User"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "User group"
}

data "aws_secretsmanager_secret" "admin_password" {
  name = "rp-${var.environment}-cognito-admin-password"
}

data "aws_secretsmanager_secret_version" "admin_password" {
  secret_id = data.aws_secretsmanager_secret.admin_password.id
}

resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.admin_email

  attributes = {
    email          = var.admin_email
    email_verified = true
  }

  temporary_password = jsondecode(
    data.aws_secretsmanager_secret_version.admin_password.secret_string
  )["password"]

  lifecycle {
    ignore_changes = [temporary_password]
  }
}

resource "aws_cognito_user_in_group" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.admin.name
  username     = aws_cognito_user.admin.username
}

# ===== Post-Authentication ウォーマー（cold-start 対策 D）=====
# ログイン成功 → 本 Lambda → query Lambda を非同期(Event)起動({"warmup":true}) → OpenSearch 暖機。
# query Lambda は別モジュール(lambda)が cognito に依存するため、循環回避で「構築ARN文字列」で参照する
# （terraform 依存を張らない）。

data "archive_file" "postauth" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/postauth"
  output_path = "${path.root}/../lambda/postauth.zip"
}

resource "aws_iam_role" "postauth" {
  name = "${var.project_name}-postauth-warmer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "postauth" {
  name = "${var.project_name}-postauth-warmer-policy"
  role = aws_iam_role.postauth.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # 暖機対象の query Lambda を非同期起動する権限のみ（構築ARNで循環回避）。
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = "arn:aws:lambda:${var.aws_region}:${var.account_id}:function:${var.project_name}-query"
      }
    ]
  })
}

resource "aws_lambda_function" "postauth" {
  filename         = data.archive_file.postauth.output_path
  function_name    = "${var.project_name}-postauth-warmer"
  role             = aws_iam_role.postauth.arn
  handler          = "handler.handler"
  runtime          = "python3.13"
  timeout          = 5
  source_code_hash = data.archive_file.postauth.output_base64sha256

  environment {
    variables = {
      WARMER_TARGET = "${var.project_name}-query"
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.postauth.name
  }

  tags = {
    Name = "${var.project_name}-postauth-warmer"
  }
}

# ログ保持 30 日（既定の自動作成ロググループは保持無期限のため、IaC 管理のグループへ出力を切替）
resource "aws_cloudwatch_log_group" "postauth" {
  name              = "/lambda/${var.project_name}-postauth-warmer"
  retention_in_days = 30
}

# Cognito が本 Lambda を呼び出す権限
resource "aws_lambda_permission" "cognito_postauth" {
  statement_id  = "AllowCognitoInvokePostAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.postauth.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
