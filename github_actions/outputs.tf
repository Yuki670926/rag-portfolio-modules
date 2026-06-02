output "role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "frontend_deploy_role_arn" {
  value       = aws_iam_role.frontend_deploy.arn
  description = "Frontendデプロイ専用ロールのARN（GitHub Secretに手動登録）"
}
