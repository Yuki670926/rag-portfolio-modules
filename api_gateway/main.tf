resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "RAG Portfolio API"

  tags = {
    Name = "${var.project_name}-api"
  }
}

# /query リソース
resource "aws_api_gateway_resource" "query" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "query"
}

# POST /query メソッド
resource "aws_api_gateway_method" "query_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Cognitoオーソライザー
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.project_name}-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# Lambda統合
resource "aws_api_gateway_integration" "query_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.query.id
  http_method             = aws_api_gateway_method.query_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.query_lambda_invoke_arn
}

# CORS用OPTIONSメソッド
resource "aws_api_gateway_method" "query_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "query_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "query_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "query_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
  }
  depends_on = [aws_api_gateway_integration.query_options]
}

# デプロイ
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    # presigned_url モジュールのルート(/upload,/status)は別モジュールで定義され、
    # ここ(api_gateway)の deployment 依存に含められない（presigned が本モジュールに依存＝循環回避）。
    # そのため新ルート追加時は root から var.deployment_revision を bump して再デプロイを強制する。
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.query.id,
      aws_api_gateway_method.query_post.id,
      aws_api_gateway_integration.query_lambda.id,
      aws_api_gateway_gateway_response.cors_4xx.id,
      aws_api_gateway_gateway_response.cors_5xx.id,
      var.deployment_revision,
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.query_lambda,
    aws_api_gateway_integration_response.query_options,
    aws_api_gateway_gateway_response.cors_4xx,
    aws_api_gateway_gateway_response.cors_5xx,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  tags = {
    Name = "${var.project_name}-stage"
  }
}

# LambdaにAPI Gatewayからの呼び出し権限を付与
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.query_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# CORS用ゲートウェイレスポンス
resource "aws_api_gateway_gateway_response" "cors_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "cors_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

# Lambda Authorizer
# （authorizer の実行ロール／ポリシーは lambda モジュール側の定義に一本化。
#   かつて本モジュールにも同名の aws_iam_role.lambda_authorizer / aws_iam_role_policy が
#   二重定義されていたが未参照の死にリソースだったため撤去。state からは root の
#   removed ブロック（destroy=false）で外し、物理ロールは lambda モジュール管理を継続。）
resource "aws_api_gateway_authorizer" "lambda" {
  name            = "${var.project_name}-lambda-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "TOKEN"
  authorizer_uri  = var.authorizer_lambda_invoke_arn
  identity_source = "method.request.header.Authorization"
  # キャッシュ 300s。TOKEN authorizer の結果はトークン単位でキャッシュされるが、ハンドラが
  # ステージ全メソッドのワイルドカード Resource を返すためメソッド間で流用されても安全
  # （旧: 特定メソッドARN返却×キャッシュで /status 403 → 一時 TTL=0。全コール二重起動を
  # 避けるため、ワイルドカード化を前提に復活）。
  authorizer_result_ttl_in_seconds = 300
}

resource "aws_lambda_permission" "api_gateway_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/authorizers/*"
}

# APIステージのスロットリング設定
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 100
    throttling_burst_limit = 200
  }
}
