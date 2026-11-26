resource "aws_ecs_cluster" "main" {
  name = local.name
}

resource "aws_cloudwatch_log_group" "svc" {
  for_each          = toset(["web", "worker", "help-center", "company-backend", "adot"])
  name              = "/ecs/${local.name}-${each.key}"
  retention_in_days = 1
}

locals {
  alb_url   = "http://${aws_lb.main.dns_name}"
  https_url = "https://${aws_cloudfront_distribution.console.domain_name}"

  secret_keys = ["DATABASE_URL", "REDIS_URL", "JWT_SECRET", "SECRET_KEY_BASE", "AR_ENC_PRIMARY_KEY", "AR_ENC_DETERMINISTIC_KEY",
  "AR_ENC_KEY_DERIVATION_SALT", "TOOL_HMAC_SECRET", "LOAD_TEST_TOKEN", "SEED_PASSWORD"]

  rails_secrets = [for k in local.secret_keys : { name = k, valueFrom = "${aws_secretsmanager_secret.app.arn}:${k}::" }]

  rails_env = [
    { name = "RAILS_ENV", value = "production" },
    { name = "RAILS_LOG_LEVEL", value = "info" },
    { name = "LLM_PROVIDER", value = "bedrock" },
    { name = "SPEECH_PROVIDER", value = "aws" },
    { name = "EMBEDDING_PROVIDER", value = "bedrock" },
    { name = "AWS_REGION", value = var.region },
    { name = "BEDROCK_MODEL_ID", value = var.bedrock_model_id },
    { name = "BEDROCK_FALLBACK_MODEL_ID", value = var.bedrock_fallback_model_id },
    { name = "BEDROCK_EMBED_MODEL_ID", value = var.bedrock_embed_model_id },
    { name = "S3_BUCKET", value = aws_s3_bucket.uploads.bucket },
    { name = "COMPANY_BACKEND_URL", value = local.alb_url },
    { name = "HELP_CENTER_URL", value = local.https_url },
    { name = "INGEST_ALLOWED_HOSTS", value = aws_lb.main.dns_name },
    { name = "EMF", value = "1" },
    { name = "RUBY_YJIT_ENABLE", value = "1" },
    { name = "DB_POOL", value = "20" },
    { name = "CABLE_WORKERS", value = "8" },
    { name = "RAILS_MAX_THREADS", value = "5" },
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4318" },
    { name = "OTEL_XRAY_IDS", value = "1" },
  ]

  # ADOT sidecar: OTLP in, AWS X-Ray out.
  adot_config = <<-YAML
    receivers:
      otlp:
        protocols:
          http:
            endpoint: 0.0.0.0:4318
    exporters:
      awsxray:
        region: ${var.region}
    service:
      pipelines:
        traces:
          receivers: [otlp]
          exporters: [awsxray]
  YAML

  adot_container = {
    name      = "adot"
    image     = "public.ecr.aws/aws-observability/aws-otel-collector:v0.41.1"
    essential = false
    cpu       = 32
    memory    = 128
    environment = [
      { name = "AOT_CONFIG_CONTENT", value = local.adot_config },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options   = { "awslogs-group" = "/ecs/${local.name}-adot", "awslogs-region" = var.region, "awslogs-stream-prefix" = "adot" }
    }
  }

  log = { for k in ["web", "worker", "help-center", "company-backend"] : k => {
    logDriver = "awslogs"
    options   = { "awslogs-group" = "/ecs/${local.name}-${k}", "awslogs-region" = var.region, "awslogs-stream-prefix" = k }
  } }
}

# ---- web: Rails puma + Action Cable, 0.5 vCPU / 1 GB x2 across two AZs -----------------------------------------

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.name}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name             = "rails"
      image            = local.images.rails
      essential        = true
      portMappings     = [{ containerPort = 3000 }]
      environment      = concat(local.rails_env, [{ name = "OTEL_SERVICE_NAME", value = "agent-desk-rails" }, { name = "WEB_CONCURRENCY", value = "1" }])
      secrets          = local.rails_secrets
      logConfiguration = local.log["web"]
    },
    local.adot_container,
  ])
}

resource "aws_ecs_service" "web" {
  name                               = "${local.name}-web"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.web.arn
  desired_count                      = var.web_desired_count
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id # one task per AZ
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "rails"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener_rule.web_api, aws_lb_listener_rule.web_cable, aws_secretsmanager_secret_version.app]

  lifecycle {
    ignore_changes = [task_definition] # application deploys (CI/OIDC or scripts/deploy.sh) roll new task definitions
  }
}

# ---- worker: Sidekiq, 0.25 vCPU / 0.5 GB ------------------------------------------------------------------------

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name              = "sidekiq"
      image             = local.images.rails
      essential         = true
      command           = ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]
      environment       = concat(local.rails_env, [{ name = "OTEL_SERVICE_NAME", value = "agent-desk-sidekiq" }, { name = "PROM_ROLE", value = "worker" }])
      secrets           = local.rails_secrets
      memoryReservation = 256
      logConfiguration  = local.log["worker"]
    },
    local.adot_container,
  ])
}

resource "aws_ecs_service" "worker" {
  name                               = "${local.name}-worker"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.worker.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  depends_on = [aws_secretsmanager_secret_version.app]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ---- help center: Next.js SSR -----------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "help_center" {
  family                   = "${local.name}-help-center"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name         = "help-center"
    image        = local.images.help_center
    essential    = true
    portMappings = [{ containerPort = 3001 }]
    environment = [
      { name = "API_URL", value = local.alb_url },
      { name = "PUBLIC_API_URL", value = local.https_url },
    ]
    logConfiguration = local.log["help-center"]
  }])
}

resource "aws_ecs_service" "help_center" {
  name                               = "${local.name}-help-center"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.help_center.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.help_center.arn
    container_name   = "help-center"
    container_port   = 3001
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}

# ---- mock company backend + demo sites --------------------------------------------------------------------------

resource "aws_ecs_task_definition" "company_backend" {
  family                   = "${local.name}-company-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name             = "company-backend"
    image            = local.images.company_backend
    essential        = true
    portMappings     = [{ containerPort = 4567 }]
    secrets          = [{ name = "TOOL_HMAC_SECRET", valueFrom = "${aws_secretsmanager_secret.app.arn}:TOOL_HMAC_SECRET::" }]
    logConfiguration = local.log["company-backend"]
  }])
}

resource "aws_ecs_service" "company_backend" {
  name                               = "${local.name}-company-backend"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.company_backend.arn
  desired_count                      = 1
  launch_type                        = "FARGATE"
  health_check_grace_period_seconds  = 30
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "company-backend"
    container_port   = 4567
  }

  depends_on = [aws_lb_listener_rule.backend, aws_secretsmanager_secret_version.app]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
