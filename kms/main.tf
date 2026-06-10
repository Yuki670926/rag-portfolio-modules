# S3用KMSキー
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 buckets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Vectors Service"
        Effect = "Allow"
        Principal = {
          Service = "indexing.s3vectors.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        # CloudFront(OAC) が SSE-KMS のフロントオブジェクトを復号するために必要。
        # OAC のバケットポリシー許可だけでは不足で、KMS キーポリシーにも CloudFront を足さないと 403 になる。
        # モジュール循環(kms→cloudfront→s3→kms)回避のため SourceArn でなく SourceAccount で account にスコープ。
        Sid    = "Allow CloudFront Decrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-s3-key"
  }
}

# S3用KMSキーエイリアス
resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# （DynamoDB 専用キーは削除：2026-06-10 設計判断 a）
# テーブルは同一データドメインの S3 用 CMK で暗号化しており、専用キーは未使用だった。
# 鍵分離の便益（爆発半径の分離）より管理簡素・コスト（$1/月）を優先し単一 CMK に統一。
# 用途分離が必要になったら鍵を再作成し、lambda ロールへの kms 権限配線とセットで導入する。

# SQS用KMSキー
resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS queues"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SQS Service"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-sqs-key"
  }
}

# SQS用KMSキーエイリアス
resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.project_name}-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

# CloudTrail用KMSキー
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail Service"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cloudtrail-key"
  }
}

# CloudTrail用KMSキーエイリアス
resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${var.project_name}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}
