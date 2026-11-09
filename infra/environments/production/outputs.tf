output "vpc_id" {
  value = module.stack.vpc_id
}

output "alb_dns_name" {
  value = module.stack.alb_dns_name
}

output "app_url" {
  value = module.stack.app_url
}

output "ecr_repository_url" {
  value = module.stack.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.stack.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.stack.ecs_service_name
}

output "task_definition_family" {
  value = module.stack.task_definition_family
}

output "rds_endpoint" {
  value = module.stack.rds_endpoint
}

output "db_secret_arn" {
  value = module.stack.db_secret_arn
}

output "log_group_name" {
  value = module.stack.log_group_name
}

output "sns_topic_arn" {
  value = module.stack.sns_topic_arn
}

output "infrastructure_dashboard_url" {
  value = module.stack.infrastructure_dashboard_url
}

output "application_dashboard_url" {
  value = module.stack.application_dashboard_url
}

output "github_deploy_role_arn" {
  value = module.stack.github_deploy_role_arn
}
