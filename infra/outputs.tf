output "alb_dns" {
  value = aws_lb.main.dns_name
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.console.domain_name
}

output "cloudfront_id" {
  value = aws_cloudfront_distribution.console.id
}

output "console_bucket" {
  value = aws_s3_bucket.console.bucket
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "cluster" {
  value = aws_ecs_cluster.main.name
}

output "ecr_repositories" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "app_security_group" {
  value = aws_security_group.app.id
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.main.cache_nodes[0].address
}

output "secret_name" {
  value = aws_secretsmanager_secret.app.name
}

output "seed_password" {
  value     = random_password.app["seed"].result
  sensitive = true
}

output "load_test_token" {
  value     = random_password.app["load_test"].result
  sensitive = true
}

output "services" {
  value = [aws_ecs_service.web.name, aws_ecs_service.worker.name, aws_ecs_service.help_center.name, aws_ecs_service.company_backend.name]
}
