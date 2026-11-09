project_name = "8byte"
environment  = "staging"
aws_region   = "ap-south-1"
owner        = "Pankaj Sharma"

alarm_email       = ""
github_repository = "pnkjshrma99/8byte-devops-assignment"

create_github_deploy_role = true
domain_name               = ""
hosted_zone_id            = ""
create_acm_certificate    = false
acm_certificate_arn       = ""

app_version          = "staging"
app_desired_count    = 1
app_min_capacity     = 1
app_max_capacity     = 4
app_use_fargate_spot = true
app_cpu              = 256
app_memory           = 512
enable_ecs_exec      = true

vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = true
enable_flow_logs   = true

db_name                  = "app"
db_username              = "app_admin"
db_instance_class        = "db.t4g.micro"
db_engine_version        = "16"
db_multi_az              = false
db_backup_retention_days = 7
db_deletion_protection   = false
db_skip_final_snapshot   = true
db_performance_insights  = false
db_monitoring_interval   = 0

log_retention_days        = 30
enable_alb_access_logs    = true
alb_logs_retention_days   = 30
enable_container_insights = true
alb_deletion_protection   = false
