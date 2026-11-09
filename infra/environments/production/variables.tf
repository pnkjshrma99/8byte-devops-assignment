variable "project_name" {
  type    = string
  default = "8byte"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "owner" {
  type    = string
  default = "Pankaj Sharma"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "alarm_email" {
  type    = string
  default = ""
}

variable "github_repository" {
  type    = string
  default = ""
}

variable "create_github_deploy_role" {
  type    = bool
  default = true
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

variable "create_acm_certificate" {
  type    = bool
  default = false
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "app_image" {
  type    = string
  default = ""
}

variable "app_version" {
  type    = string
  default = "bootstrap"
}

variable "app_desired_count" {
  type    = number
  default = 1
}

variable "app_min_capacity" {
  type    = number
  default = 1
}

variable "app_max_capacity" {
  type    = number
  default = 4
}

variable "app_use_fargate_spot" {
  type    = bool
  default = false
}

variable "app_cpu" {
  type    = number
  default = 256
}

variable "app_memory" {
  type    = number
  default = 512
}

variable "enable_ecs_exec" {
  type    = bool
  default = false
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "enable_flow_logs" {
  type    = bool
  default = true
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_username" {
  type    = string
  default = "app_admin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_engine_version" {
  type    = string
  default = "16"
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "db_performance_insights" {
  type    = bool
  default = false
}

variable "db_monitoring_interval" {
  type    = number
  default = 0
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "enable_alb_access_logs" {
  type    = bool
  default = true
}

variable "alb_logs_retention_days" {
  type    = number
  default = 90
}

variable "enable_container_insights" {
  type    = bool
  default = true
}
