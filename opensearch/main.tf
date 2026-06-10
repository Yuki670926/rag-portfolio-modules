data "aws_caller_identity" "current" {}

# NextGen コレクショングループ（generation=NEXTGEN）。
# Classic から移行：コレクションを本グループに所属させて NextGen 化する。
# NextGen は compute/storage 分離＋scale-to-zero（idle≈$0）。standby_replicas は NextGen 必須=ENABLED。
resource "aws_opensearchserverless_collection_group" "main" {
  name             = "${var.project_name}-group"
  generation       = "NEXTGEN"
  standby_replicas = "ENABLED"
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.project_name}-enc"
  type = "encryption"
  # kms_key_arn 指定時は CMK（AWSOwnedKey=false + KmsARN）、未指定時は AWS 所有キー。
  # 注意：既存 collection の鍵は変更不可（公式仕様）。鍵を変える場合は collection の
  # 作り直しが必要（派生データなので再 ingest で復元可能）。
  policy = var.kms_key_arn != "" ? jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-collection"]
    }]
    AWSOwnedKey = false
    KmsARN      = var.kms_key_arn
    }) : jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-collection"]
    }]
    AWSOwnedKey = true
  })
}

locals {
  os_net_rules = [
    {
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-collection"]
    },
    {
      ResourceType = "dashboard"
      Resource     = ["collection/${var.project_name}-collection"]
    }
  ]
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-net"
  type = "network"
  # enable_private_networking=true のとき公開アクセスを閉じ、aoss 専用 VPC エンドポイント
  # (SourceVPCEs)からのみ到達可能にする＝ネットワーク隔離。false のときは従来どおり公開。
  # ※ 三項は jsonencode の文字列結果に掛ける（オブジェクトの三項は両分岐で型が一致せず不可）。
  policy = var.enable_private_networking ? jsonencode([{
    Rules           = local.os_net_rules
    AllowFromPublic = false
    SourceVPCEs     = [var.aoss_vpc_endpoint_id]
    }]) : jsonencode([{
    Rules           = local.os_net_rules
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_access_policy" "main" {
  name = "${var.project_name}-access"
  type = "data"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-collection"]
        Permission   = ["aoss:CreateCollectionItems", "aoss:DeleteCollectionItems", "aoss:UpdateCollectionItems", "aoss:DescribeCollectionItems"]
      },
      {
        ResourceType = "index"
        Resource     = ["index/${var.project_name}-collection/*"]
        Permission   = ["aoss:CreateIndex", "aoss:DeleteIndex", "aoss:UpdateIndex", "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
      }
    ]
    Principal = [
      var.ingest_lambda_role_arn,
      var.query_lambda_role_arn,
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    ]
  }])
}

resource "aws_opensearchserverless_collection" "main" {
  name                  = "${var.project_name}-collection"
  type                  = "VECTORSEARCH"
  collection_group_name = aws_opensearchserverless_collection_group.main.name # NextGen 群へ所属＝NextGen 化（Classic を置換）

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.main
  ]

  tags = {
    Name = "${var.project_name}-collection"
  }
}
