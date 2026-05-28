output "budget_name" {
  value = aws_budgets_budget.monthly.name
}

output "alert_email" {
  value     = nonsensitive(jsondecode(ephemeral.aws_secretsmanager_secret_version.alert_email.secret_string)["email"])
  sensitive = true
}
