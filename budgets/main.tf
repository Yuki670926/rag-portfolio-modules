terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ephemeral resourceでtfstateに保存しない
ephemeral "aws_secretsmanager_secret_version" "alert_email" {
  secret_id = "rp-${var.environment}-alert-email"
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [nonsensitive(jsondecode(ephemeral.aws_secretsmanager_secret_version.alert_email.secret_string)["email"])]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [nonsensitive(jsondecode(ephemeral.aws_secretsmanager_secret_version.alert_email.secret_string)["email"])]
  }
}
