resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# デフォルト SG の無効化（CKV2_AWS_12）：引数なしで Terraform 管理にすると
# 全 in/out ルールが剥奪される。本構成の SG は全て明示定義
# （vpc-endpoint-sg / lambda-sg）でデフォルト SG への参照は無いため動作影響ゼロ。
# 「うっかりデフォルト SG を使う」事故の防止が目的。
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-default-sg-locked"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
  }
}

# プライベートサブネット用ルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# ルートテーブルとサブネットの関連付け
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VPCエンドポイント用セキュリティグループ
resource "aws_security_group" "vpc_endpoint" {
  name        = "${var.project_name}-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-vpc-endpoint-sg"
  }
}

# S3 ゲートウェイエンドポイント
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

# DynamoDB ゲートウェイエンドポイント
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-northeast-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-dynamodb-endpoint"
  }
}

# Bedrock インターフェースエンドポイント
resource "aws_vpc_endpoint" "bedrock" {
  count               = var.enable_private_networking ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-bedrock-endpoint"
  }
}

# （SQS の Interface EP は削除：DLQ への配送は Lambda サービス側が VPC 外で行うため、
#   関数コードも SQS を直接呼ばず、VPC 内からの経路は不要。固定費 約$20/月の削減）

# Bedrock Agent インターフェースエンドポイント（KBのStartIngestionJob用）
resource "aws_vpc_endpoint" "bedrock_agent" {
  # KB（s3_vectors/dual）利用時のみ。opensearch 単独では不要な固定費を作らない
  count               = var.enable_private_networking && var.kb_endpoints_enabled ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.bedrock-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  tags = {
    Name = "${var.project_name}-bedrock-agent-endpoint"
  }
}

# Bedrock Agent Runtime インターフェースエンドポイント（KBのRetrieve用）
resource "aws_vpc_endpoint" "bedrock_agent_runtime" {
  # KB（s3_vectors/dual）利用時のみ
  count               = var.enable_private_networking && var.kb_endpoints_enabled ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.bedrock-agent-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  tags = {
    Name = "${var.project_name}-bedrock-agent-runtime-endpoint"
  }
}

# SSM インターフェースエンドポイント（VPC内 Lambda が SSM Parameter からベクトルストア
# エンドポイント等を取得するため。opensearch×VPC で query/ingest が利用）
resource "aws_vpc_endpoint" "ssm" {
  # SSM param は OpenSearch エンドポイント配布専用のため opensearch/dual のときのみ
  count               = var.enable_private_networking && var.ssm_endpoint_enabled ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssm-endpoint"
  }
}

# OpenSearch Serverless データプレーン VPC エンドポイント（NextGen 用・標準 PrivateLink）。
# NextGen の collection エンドポイント(*.aoss.{region}.on.aws)は、Classic 専用の
# aws_opensearchserverless_vpc_endpoint（aoss.amazonaws.com 系のみ解決）では到達できない。
# 標準 Interface EP（service: aoss-data）＋ private DNS で *.aoss.{region}.on.aws を解決し、
# この vpce id を network policy の SourceVPCEs に指定して VPC 隔離する。
# 参考: https://docs.aws.amazon.com/opensearch-service/latest/developerguide/serverless-vpc.html
resource "aws_vpc_endpoint" "aoss_data" {
  # vector_store_type=s3_vectors のときは aoss に接続しないため EP を作らない
  # （Interface EP は存在するだけで課金されるため、不要な固定費 約$20/月 を回避）。
  count               = var.enable_private_networking && var.aoss_endpoint_enabled ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-northeast-1.aoss-data"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-aoss-data-endpoint"
  }
}

# Lambda用セキュリティグループ
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}
