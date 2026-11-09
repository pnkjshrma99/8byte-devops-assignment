provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
        Owner       = var.owner
      },
      var.tags
    )
  }
}

module "stack" {
  source = "../../modules/stack"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  owner        = var.owner
  tags         = var.tags

  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  enable_flow_logs   = var.enable_flow_logs

  domain_name            = var.domain_name
  hosted_zone_id         = var.hosted_zone_id
  create_acm_certificate = var.create_acm_certificate
  acm_certificate_arn    = var.acm_certificate_arn

  app_image               = var.app_image
  app_version             = var.app_version
  app_cpu                 = var.app_cpu
  app_memory              = var.app_memory
  app_desired_count       = var.app_desired_count
  app_min_capacity        = var.app_min_capacity
  app_max_capacity        = var.app_max_capacity
  app_use_fargate_spot    = var.app_use_fargate_spot
  enable_ecs_exec         = var.enable_ecs_exec
  alb_deletion_protection = var.alb_deletion_protection

  db_name                  = var.db_name
  db_username              = var.db_username
  db_instance_class        = var.db_instance_class
  db_engine_version        = var.db_engine_version
  db_multi_az              = var.db_multi_az
  db_backup_retention_days = var.db_backup_retention_days
  db_deletion_protection   = var.db_deletion_protection
  db_skip_final_snapshot   = var.db_skip_final_snapshot
  db_performance_insights  = var.db_performance_insights
  db_monitoring_interval   = var.db_monitoring_interval

  log_retention_days        = var.log_retention_days
  enable_alb_access_logs    = var.enable_alb_access_logs
  alb_logs_retention_days   = var.alb_logs_retention_days
  enable_container_insights = var.enable_container_insights
  alarm_email               = var.alarm_email

  github_repository         = var.github_repository
  create_github_deploy_role = var.create_github_deploy_role
}
