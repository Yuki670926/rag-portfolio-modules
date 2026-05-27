data "archive_file" "presigned_url" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/presigned_url"
  output_path = "${path.root}/../lambda/presigned_url.zip"
}

# presigned-url Lambda IAMロール
resource "aws_iam_role" "presigned_url" {
  name = "${var.project_name}-presigned-url-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# presigned-url Lambda IAMポリシー
resource "aws_iam_role_policy" "presigned_url" {
  name = "${var.project_name}-presigned-url-lambda-policy"
  role = aws_iam_role.presigned_url.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.documents_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "presigned_url" {
  filename         = data.archive_file.presigned_url.output_path
  function_name    = "${var.project_name}-presigned-url"
  role             = aws_iam_role.presigned_url.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.presigned_url.output_base64sha256

  environment {
    variables = {
      DOCUMENTS_BUCKET = var.documents_bucket_name
    }
  }

  tags = {
    Name = "${var.project_name}-presigned-url"
  }
}

resource "aws_api_gateway_resource" "upload" {
  rest_api_id = var.rest_api_id
  parent_id   = var.root_resource_id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = var.lambda_authorizer_id
}

resource "aws_api_gateway_integration" "upload_lambda" {
  rest_api_id             = var.rest_api_id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presigned_url.invoke_arn
}

resource "aws_api_gateway_method" "upload_options" {
  rest_api_id   = var.rest_api_id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "upload_options" {
  rest_api_id = var.rest_api_id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://${var.cloudfront_domain}'"
  }
  depends_on = [aws_api_gateway_integration.upload_options]
}

resource "aws_lambda_permission" "api_gateway_presigned" {
  statement_id  = "AllowAPIGatewayInvokePresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.execution_arn}/*/*"
}
