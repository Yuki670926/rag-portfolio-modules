# rag-portfolio-modules

RAG Portfolioプロジェクトで使用するTerraformモジュール集です。

## モジュール一覧

| モジュール | 説明 |
|-----------|------|
| vpc | VPC・サブネット |
| s3 | S3バケット（documents・frontend） |
| cognito | Cognitoユーザープール・クライアント |
| lambda | Lambda関数（ingest・query） |
| opensearch | OpenSearch Serverlessコレクション |
| api_gateway | API Gateway（REST API・Cognito認証） |
| cloudfront | CloudFrontディストリビューション |
| presigned_url | S3署名付きURL発行Lambda |
| github_actions | GitHub Actions OIDC認証 |

## バージョン管理

各環境で使用するバージョンを指定して参照します。

```hcl
module "vpc" {
  source = "github.com/Yuki670926/rag-portfolio-modules//vpc?ref=v1.0.0"
}
```

## バージョン履歴

| バージョン | 内容 |
|-----------|------|
| v1.0.0 | 初期リリース |
