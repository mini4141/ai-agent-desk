# Alarms for the runbooks in docs/runbooks/: ALB 5xx, p95 latency, Sidekiq queue latency and dead set.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "Web 5xx responses. Runbook: docs/runbooks/web-5xx-or-slow.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_p95" {
  alarm_name          = "${local.name}-alb-p95-latency"
  alarm_description   = "p95 target response time above 1.5 s. Runbook: docs/runbooks/web-5xx-or-slow.md"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1.5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "sidekiq_latency" {
  alarm_name          = "${local.name}-sidekiq-queue-latency"
  alarm_description   = "Oldest queued job waiting > 60 s. Runbook: docs/runbooks/sidekiq-dead-set-and-queue-latency.md"
  namespace           = "AgentDesk/Sidekiq"
  metric_name         = "QueueLatencySeconds"
  dimensions          = { Service = "worker" }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 60
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "sidekiq_dead" {
  alarm_name          = "${local.name}-sidekiq-dead-set"
  alarm_description   = "Jobs exhausted their retries. Runbook: docs/runbooks/sidekiq-dead-set-and-queue-latency.md"
  namespace           = "AgentDesk/Sidekiq"
  metric_name         = "DeadSetSize"
  dimensions          = { Service = "worker" }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Chat latency p95 per stage (ms)", region = var.region, stat = "p95", period = 60
          metrics = [for s in ["retrieval_ms", "llm_first_token_ms", "end_to_end_ms"] : ["AgentDesk/Latency", s, "Channel", "web_chat"]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB requests and 5xx", region = var.region, stat = "Sum", period = 60
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix], [".", "HTTPCode_Target_5XX_Count", ".", "."]]
        }
      },
    ]
  })
}
