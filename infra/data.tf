resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
}

# PostgreSQL 17 with the pgvector extension (CREATE EXTENSION vector runs in the first migration).
resource "aws_db_instance" "main" {
  identifier                 = local.name
  engine                     = "postgres"
  engine_version             = "17"
  instance_class             = "db.t4g.micro"
  allocated_storage          = 20
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = "agent_desk_production"
  username                   = "agentdesk"
  password                   = random_password.db.result
  db_subnet_group_name       = aws_db_subnet_group.main.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  publicly_accessible        = false
  multi_az                   = false
  backup_retention_period    = 1
  skip_final_snapshot        = true
  deletion_protection        = false
  apply_immediately          = true
  auto_minor_version_upgrade = true
}

resource "aws_elasticache_subnet_group" "main" {
  name       = local.name
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "main" {
  cluster_id           = local.name
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
}

# ---- S3 ----------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "uploads" {
  bucket        = "${local.name}-uploads-${local.account}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "console" {
  bucket        = "${local.name}-console-${local.account}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "console" {
  bucket                  = aws_s3_bucket.console.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- secrets -----------------------------------------------------------------------------------------------------

resource "random_password" "app" {
  for_each = toset(["jwt", "secret_key_base", "ar_primary", "ar_deterministic", "ar_salt", "tool_hmac", "load_test", "seed"])
  length   = each.key == "secret_key_base" ? 64 : 32
  special  = false
}

resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.name}/app"
  recovery_window_in_days = 0 # delete immediately on destroy
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DATABASE_URL               = "postgres://${aws_db_instance.main.username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${aws_db_instance.main.db_name}"
    REDIS_URL                  = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:6379/0"
    JWT_SECRET                 = random_password.app["jwt"].result
    SECRET_KEY_BASE            = random_password.app["secret_key_base"].result
    AR_ENC_PRIMARY_KEY         = random_password.app["ar_primary"].result
    AR_ENC_DETERMINISTIC_KEY   = random_password.app["ar_deterministic"].result
    AR_ENC_KEY_DERIVATION_SALT = random_password.app["ar_salt"].result
    TOOL_HMAC_SECRET           = random_password.app["tool_hmac"].result
    LOAD_TEST_TOKEN            = random_password.app["load_test"].result
    SEED_PASSWORD              = random_password.app["seed"].result
  })
}
