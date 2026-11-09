resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db"
  subnet_ids = aws_subnet.private_db[*].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-db" })
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.name_prefix}-pg"
  family      = local.db_parameter_group_family
  description = "PostgreSQL settings for ${local.name_prefix}"

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  tags = local.common_tags
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.db_monitoring_interval > 0 ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.db_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "this" {
  identifier = local.db_identifier
  engine     = "postgres"

  # Use a major version so RDS can apply minor upgrades. The ignore_changes
  # below prevents a permanent diff when the provider reads the resolved
  # minor version back from AWS.
  engine_version = var.db_engine_version

  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_days
  backup_window           = "18:00-19:00"
  maintenance_window      = "Sun:19:00-Mon:20:00"
  copy_tags_to_snapshot   = true
  apply_immediately       = var.environment != "production"

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  deletion_protection         = var.db_deletion_protection
  skip_final_snapshot         = var.db_skip_final_snapshot
  final_snapshot_identifier   = var.db_skip_final_snapshot ? null : local.db_final_snapshot_id

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  performance_insights_enabled          = var.db_performance_insights
  performance_insights_retention_period = var.db_performance_insights ? 7 : null
  monitoring_interval                   = var.db_monitoring_interval
  monitoring_role_arn                   = var.db_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, { Name = local.db_identifier })

  timeouts {
    create = "60m"
    update = "80m"
    delete = "60m"
  }

  lifecycle {
    ignore_changes = [engine_version]
  }
}
