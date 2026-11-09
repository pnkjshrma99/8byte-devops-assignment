variable "project_name" {
  description = "Short project name used as a resource prefix."
  type        = string
  default     = "8byte"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be either staging or production."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Team or person responsible for the stack."
  type        = string
  default     = "DevOps"
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}

# Network -------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 recommended."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway (cheaper) instead of one per AZ (HA)."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create a free S3 gateway VPC endpoint for private subnets."
  type        = bool
  default     = true
}

# TLS / DNS -----------------------------------------------------------------

variable "domain_name" {
  description = "Optional application DNS name, e.g. app.example.com."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Optional Route 53 hosted zone ID used for DNS validation and the app alias."
  type        = string
  default     = ""
}

variable "create_acm_certificate" {
  description = "Create and DNS-validate an ACM certificate. Requires domain_name and hosted_zone_id."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN. Takes precedence over create_acm_certificate."
  type        = string
  default     = ""
}

# Application ---------------------------------------------------------------

variable "app_port" {
  description = "Container port exposed by the application."
  type        = number
  default     = 8000
}

variable "app_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "app_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "app_desired_count" {
  description = "Initial number of tasks. Autoscaling manages it afterwards."
  type        = number
  default     = 1
}

variable "app_min_capacity" {
  description = "Autoscaling minimum task count."
  type        = number
  default     = 1
}

variable "app_max_capacity" {
  description = "Autoscaling maximum task count."
  type        = number
  default     = 4
}

variable "app_use_fargate_spot" {
  description = "Use a Fargate Spot capacity provider mix for the service."
  type        = bool
  default     = false
}

variable "app_image" {
  description = "Full container image URI. Empty uses a tiny bootstrap image until CI deploys the real app."
  type        = string
  default     = ""
}

variable "app_version" {
  description = "Value exposed by the app as APP_VERSION."
  type        = string
  default     = "bootstrap"
}

variable "log_level" {
  description = "Application log level."
  type        = string
  default     = "INFO"
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for interactive troubleshooting."
  type        = bool
  default     = false
}

variable "alb_deletion_protection" {
  description = "Protect the ALB from accidental deletion."
  type        = bool
  default     = false
}

# Database ------------------------------------------------------------------

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "RDS master username."
  type        = string
  default     = "app_admin"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL major or minor version."
  type        = string
  default     = "16"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS storage for autoscaling in GiB."
  type        = number
  default     = 100
}

variable "db_multi_az" {
  description = "Enable a Multi-AZ RDS deployment."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "RDS automated backup retention in days."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Prevent deletion of the RDS instance."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when the database is deleted."
  type        = bool
  default     = true
}

variable "db_performance_insights" {
  description = "Enable RDS Performance Insights."
  type        = bool
  default     = false
}

variable "db_monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 disables it)."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.db_monitoring_interval)
    error_message = "db_monitoring_interval must be one of 0, 1, 5, 10, 15, 30, 60."
  }
}

# Observability -------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention for application and flow logs."
  type        = number
  default     = 30
}

variable "enable_alb_access_logs" {
  description = "Write ALB access logs to S3."
  type        = bool
  default     = true
}

variable "alb_logs_retention_days" {
  description = "Days to retain ALB access logs in S3."
  type        = number
  default     = 90
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights."
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Optional email subscribed to the SNS alert topic."
  type        = string
  default     = ""
}

# CI/CD ---------------------------------------------------------------------

variable "github_repository" {
  description = "GitHub repository in owner/name form, used in the OIDC trust policy."
  type        = string
  default     = ""
}

variable "create_github_deploy_role" {
  description = "Create a GitHub Actions OIDC deployment role for this environment."
  type        = bool
  default     = true
}
