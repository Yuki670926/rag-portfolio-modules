# ------------------------------------------------------------
# S3 Vectors モジュール
#   Bedrock Knowledge Base のベクトルストアとして使用する
#   S3 Vector Bucket と Vector Index を作成する。
#   OpenSearch Serverless からの移行先（フルマネージド・低コスト）。
# ------------------------------------------------------------

# ベクトルバケット（保存時暗号化：設計原則に従いKMS(SSE-KMS)を使用）
resource "aws_s3vectors_vector_bucket" "main" {
  vector_bucket_name = "${var.project_name}-vectors"

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = var.kms_key_arn
  }

  # dev環境での作り直しを容易にするため、中身ごと破棄を許可
  force_destroy = var.force_destroy
}

# ベクトルインデックス
#   dimension/distance_metric は埋め込みモデル(Titan V2=1024次元)に一致させる。
#   metadata: Bedrock KB が使う予約メタデータキーを非フィルタ対象として登録する。
resource "aws_s3vectors_index" "main" {
  vector_bucket_name = aws_s3vectors_vector_bucket.main.vector_bucket_name
  index_name         = "${var.project_name}-index"
  data_type          = "float32"
  dimension          = var.dimension
  distance_metric    = var.distance_metric

  metadata_configuration {
    non_filterable_metadata_keys = [
      "AMAZON_BEDROCK_TEXT",
      "AMAZON_BEDROCK_METADATA",
    ]
  }
}
