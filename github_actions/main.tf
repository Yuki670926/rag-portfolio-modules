terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_username}/${var.github_repo}:environment:${var.environment}"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ===== Frontend デプロイ専用ロール（最小権限） =====
# deploy-frontend.yml 用。S3同期 + CloudFront invalidation のみ許可。
# 信頼条件は GitHub Environment 単位（apply用ロールと同じ環境スコープ）。
# deploy-frontend.yml が environment を指定するため、OIDC の sub は
# ref:refs/heads/main ではなく environment:<env> 形式になる（GitHub の仕様）。
resource "aws_iam_role" "frontend_deploy" {
  name = "${var.project_name}-frontend-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_username}/${var.github_repo}:environment:${var.environment}"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Frontend デプロイの最小権限ポリシー
resource "aws_iam_role_policy" "frontend_deploy" {
  name = "${var.project_name}-frontend-deploy-policy"
  role = aws_iam_role.frontend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3: フロントバケットへの同期（sync --delete）
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.frontend_bucket_arn,
          "${var.frontend_bucket_arn}/*"
        ]
      },
      {
        # KMS: SSE-KMS暗号化バケットへのPut/読み取り
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = var.s3_kms_key_arn
      },
      {
        # CloudFront: キャッシュ無効化
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation"]
        Resource = var.cloudfront_distribution_arn
      }
    ]
  })
}
