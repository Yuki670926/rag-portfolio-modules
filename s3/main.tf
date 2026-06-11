# PDF保存用バケット
resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-documents-${var.account_id}"

  tags = {
    Name = "${var.project_name}-documents"
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

# documents バケットの誤破壊ガード（prod のみ）。
# lifecycle.prevent_destroy は Terraform の制約でリテラルのみ（変数不可）のため、
# バケット本体に付けると全環境一律になってしまう。代わりに prevent_destroy 付きの
# ガードリソースを count で環境分岐させる：バケットの destroy／置換は
# triggers_replace 経由でこのガードの置換を要求し、prevent_destroy がそれを
# 拒否することで間接的にバケットを守る（正本＝PDF の最後の砦。versioning／
# force_destroy=false と併せた三段構え）。
# 注意：保護の解除（true→false）もガード自身の destroy になるため拒否される。
# 解除時はこの prevent_destroy を一時的に false にする 2 段階（それ自体が誤操作ガード）。
resource "terraform_data" "documents_destroy_guard" {
  count            = var.prevent_destroy ? 1 : 0
  triggers_replace = [aws_s3_bucket.documents.id]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = var.ingest_lambda_arn
    # 作成＝索引化、削除＝索引からの削除伝播（両ストアの整合維持）
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".pdf"
  }
}

# フロントホスティング用バケット
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.account_id}"

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["https://${var.cloudfront_domain}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# documentsバケット暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# frontendバケット暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# フロントエンド設定ファイル
resource "aws_s3_object" "config" {
  bucket        = aws_s3_bucket.frontend.id
  key           = "config.json"
  content_type  = "application/json"
  cache_control = "no-cache, no-store, must-revalidate"

  content = jsonencode({
    API_URL           = var.api_url
    USER_POOL_ID      = var.user_pool_id
    CLIENT_ID         = var.client_id
    REGION            = var.aws_region
    DOCUMENTS_BUCKET  = "${var.project_name}-documents-${var.account_id}"
    VECTOR_STORE_TYPE = var.vector_store_type # フロントが dual のときだけモードトグルを表示
  })
}

# アクセスログ保存用バケット
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-access-logs-${var.account_id}"

  tags = {
    Name = "${var.project_name}-access-logs"
  }
}

# パブリックアクセスブロック
resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# KMS暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# ライフサイクルポリシー（365日で削除）
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "access-logs-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }
  }
}

# documentsバケットのアクセスログ設定
resource "aws_s3_bucket_logging" "documents" {
  bucket        = aws_s3_bucket.documents.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "documents/"
}

# frontendバケットのアクセスログ設定
resource "aws_s3_bucket_logging" "frontend" {
  bucket        = aws_s3_bucket.frontend.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "frontend/"
}
