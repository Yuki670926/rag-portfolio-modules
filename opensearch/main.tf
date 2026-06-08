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
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-collection"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.project_name}-net"
  type = "network"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-collection"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${var.project_name}-collection"]
      }
    ]
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
