# ------------------------------------------------------------
# Bedrock Knowledge Base モジュール
#   S3 Vectors をベクトルストアとする Knowledge Base を作成する。
#   チャンキング・埋め込み・ベクトル投入をKBが巻き取り、
#   自前のRAGパイプライン(ingest Lambda)を大幅に簡素化する。
# ------------------------------------------------------------

# ===== IAMサービスロール =====
#   Bedrockサービスが引き受け、以下を実行するための権限を付与する：
#     - 埋め込みモデル(Titan)の呼び出し / データソースS3の読み取り
#     - S3 Vectors への読み書き / KMSによる復号・暗号化

# 信頼ポリシー：Bedrockサービスがこのロールを引き受けられるようにする
# confused deputy対策として SourceAccount / SourceArn で限定する
data "aws_iam_policy_document" "kb_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${var.aws_region}:${var.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "kb" {
  name               = "${var.project_name}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume.json
}

# 権限ポリシー本体
data "aws_iam_policy_document" "kb_permissions" {
  # 埋め込みモデル(Titan)の呼び出し
  statement {
    sid     = "InvokeEmbeddingModel"
    effect  = "Allow"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0",
    ]
  }

  # データソース(documents S3バケット)の読み取り
  statement {
    sid    = "ReadDocumentsBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.documents_bucket_arn,
      "${var.documents_bucket_arn}/*",
    ]
  }

  # S3 Vectors への読み書き（ベクトルの投入・検索）
  statement {
    sid    = "S3VectorsAccess"
    effect = "Allow"
    actions = [
      "s3vectors:GetVectors",
      "s3vectors:PutVectors",
      "s3vectors:QueryVectors",
      "s3vectors:DeleteVectors",
      "s3vectors:GetIndex",
      "s3vectors:ListVectors",
    ]
    resources = [
      var.vector_bucket_arn,
      "${var.vector_bucket_arn}/*",
    ]
  }

  # KMSキーによる復号/暗号化
  statement {
    sid    = "KmsDecryptEncrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "kb" {
  name   = "${var.project_name}-kb-policy"
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_permissions.json
}

# ===== Knowledge Base 本体 =====

# 埋め込みモデル(Titan V2)のARNを取得する
data "aws_bedrock_foundation_model" "embedding" {
  model_id = "amazon.titan-embed-text-v2:0"
}

resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-kb"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = data.aws_bedrock_foundation_model.embedding.model_arn

      # 次元数を埋め込みモデルに明示的に一致させる(Titan V2 = 1024)
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.dimension
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  # ベクトルストアとして S3 Vectors を指定する
  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      vector_index_arn = var.vector_index_arn
    }
  }

  # IAMロールの権限が伝播してからKBを作成する
  depends_on = [aws_iam_role_policy.kb]
}

# データソース：documents S3バケット（セマンティックチャンキング）
resource "aws_bedrockagent_data_source" "main" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "${var.project_name}-s3-datasource"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.documents_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "SEMANTIC"
      semantic_chunking_configuration {
        max_tokens                      = 300
        buffer_size                     = 0
        breakpoint_percentile_threshold = 95
      }
    }
  }
}
