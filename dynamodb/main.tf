locals {
  name_prefix = var.project_name
}

resource "aws_dynamodb_table" "conversations" {
  name         = "${local.name_prefix}-conversations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "timestamp"
  # 削除保護（prod のみ true）：会話履歴は再生成不能の正本。誤 destroy・置換による
  # 不可逆な消失を API レベルで拒否する（PITR はテーブル削除そのものは防げない）
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${local.name_prefix}-conversations"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # 正本データ保護（大単元21）：誤操作・誤上書きからの復旧用にPITRを有効化
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "sessions" {
  name         = "${local.name_prefix}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "last_accessed_at"
  # 削除保護（prod のみ true）：conversations と方針を揃える（追加コストなし・in-place）
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "last_accessed_at"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "${local.name_prefix}-sessions"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # 正本データ保護（大単元21）：誤操作・誤上書きからの復旧用にPITRを有効化
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "pdf_indexes" {
  name         = "${local.name_prefix}-pdf-indexes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "pdf_name"
  # 削除保護（prod のみ true）：派生データ（再 ingest で再生成可）だが方針を揃える
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "pdf_name"
    type = "S"
  }

  tags = {
    Name = "${local.name_prefix}-pdf-indexes"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # 正本データ保護（大単元21）：誤操作・誤上書きからの復旧用にPITRを有効化
  point_in_time_recovery {
    enabled = true
  }
}