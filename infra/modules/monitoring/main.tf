# =============================================================================
# Module: Monitoring — CloudWatch + Budgets
# =============================================================================

variable "project_name" {
  type = string
}

variable "alert_email" {
  type    = string
  default = "admin@aurameet.live"
}

# --- SNS Topic for alerts ---

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  tags = { Component = "monitoring" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- CloudWatch Alarm: App Runner 5xx errors ---

resource "aws_cloudwatch_metric_alarm" "apprunner_5xx" {
  alarm_name          = "${var.project_name}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxStatusResponses"
  namespace           = "AWS/AppRunner"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "App Runner 5xx errors > 10 in 5 min"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project_name}-api"
  }

  tags = { Component = "monitoring" }
}

# --- CloudWatch Alarm: App Runner latency ---

resource "aws_cloudwatch_metric_alarm" "apprunner_latency" {
  alarm_name          = "${var.project_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestLatency"
  namespace           = "AWS/AppRunner"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 5000 # 5 seconds
  alarm_description   = "App Runner p99 latency > 5s"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project_name}-api"
  }

  tags = { Component = "monitoring" }
}

# --- Budget: $20/month guard ---

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
