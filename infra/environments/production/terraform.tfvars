project_name = "8byte"
environment  = "production"
aws_region   = "ap-south-1"
owner        = "Pankaj Sharma"

alarm_email       = "pankajsharma98930@gmail.com"
github_repository = "pnkjshrma99/8byte-devops-assignment"

create_github_deploy_role = true
domain_name               = ""
hosted_zone_id            = ""
create_acm_certificate    = false
acm_certificate_arn       = ""

app_version          = "production"
app_desired_count    = 2
app_min_capacity     = 2
app_max_capacity     = 10
app_use_fargate_spot = false
app_cpu              = 512
app_memory           = 1024
enable_ecs_exec      = false

vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = false
enable_flow_logs   = true

db_name                  = "app"
db_username              = "app_admin"
db_instance_class        = "db.t4g.small"
db_engine_version        = "16"
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true
db_skip_final_snapshot   = false
db_performance_insights  = true
db_monitoring_interval   = 60

log_retention_days        = 90
enable_alb_access_logs    = true
alb_logs_retention_days   = 90
enable_container_insights = true
alb_deletion_protection   = true
