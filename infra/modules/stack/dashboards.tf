locals {
  alb_requests   = ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Sum", label = "Requests" }]
  alb_target_5xx = ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Sum", label = "Target 5xx" }]
  alb_elb_5xx    = ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Sum", label = "ELB 5xx" }]
  alb_latency    = ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "p95", label = "p95 latency" }]
  alb_healthy    = ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Average", label = "Healthy hosts" }]
  alb_unhealthy  = ["AWS/ApplicationELB", "UnhealthyHostCount", "LoadBalancer", aws_lb.this.arn_suffix, { stat = "Average", label = "Unhealthy hosts" }]

  ecs_cpu     = ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.app.name, { stat = "Average", label = "CPU %" }]
  ecs_memory  = ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.app.name, { stat = "Average", label = "Memory %" }]
  ecs_running = ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.app.name, { stat = "Average", label = "Running tasks" }]
  ecs_desired = ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", aws_ecs_cluster.this.name, "ServiceName", aws_ecs_service.app.name, { stat = "Average", label = "Desired tasks" }]

  rds_cpu     = ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "CPU %" }]
  rds_storage = ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "Free storage (bytes)" }]
  rds_conns   = ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "Connections" }]
  rds_memory  = ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "Freeable memory (bytes)" }]
  rds_read    = ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "Read IOPS" }]
  rds_write   = ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", aws_db_instance.this.identifier, { stat = "Average", label = "Write IOPS" }]

  app_requests = ["8Byte/App", "RequestCount", "Service", local.service_name, "Environment", var.environment, { stat = "Sum", label = "Requests" }]
  app_errors   = ["8Byte/App", "ErrorCount", "Service", local.service_name, "Environment", var.environment, { stat = "Sum", label = "5xx responses" }]
  app_latency  = ["8Byte/App", "Latency", "Service", local.service_name, "Environment", var.environment, { stat = "Average", label = "Average latency" }]
  app_p50      = ["8Byte/App", "Latency", "Service", local.service_name, "Environment", var.environment, { stat = "p50", label = "p50" }]
  app_p90      = ["8Byte/App", "Latency", "Service", local.service_name, "Environment", var.environment, { stat = "p90", label = "p90" }]
  app_p99      = ["8Byte/App", "Latency", "Service", local.service_name, "Environment", var.environment, { stat = "p99", label = "p99" }]

  app_error_rate = [
    { expression = "100 * m2 / m1", label = "Error rate %", id = "e1" },
    ["8Byte/App", "RequestCount", "Service", local.service_name, "Environment", var.environment, { id = "m1", stat = "Sum", visible = false }],
    ["8Byte/App", "ErrorCount", "Service", local.service_name, "Environment", var.environment, { id = "m2", stat = "Sum", visible = false }],
  ]

  infrastructure_dashboard = {
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# 8Byte ${var.environment} - infrastructure\nALB, ECS, RDS and network health. Runbook: ${local.runbook_url}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "ALB requests"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_requests]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "ALB target 5xx"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_target_5xx, local.alb_elb_5xx]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "ALB p95 latency"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_latency]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 6
        properties = {
          title   = "Healthy targets"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_healthy]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 6
        properties = {
          title   = "Unhealthy targets"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_unhealthy]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 6
        properties = {
          title   = "ECS tasks"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.ecs_running, local.ecs_desired]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "ECS CPU"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.ecs_cpu]
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "ECS memory"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.ecs_memory]
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "RDS CPU"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_cpu]
          yAxis = {
            left = { min = 0, max = 100 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 8
        height = 6
        properties = {
          title   = "RDS free storage"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_storage]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 20
        width  = 8
        height = 6
        properties = {
          title   = "RDS connections"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_conns]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 20
        width  = 8
        height = 6
        properties = {
          title   = "RDS IOPS"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_read, local.rds_write]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 26
        width  = 24
        height = 6
        properties = {
          title  = "Recent application errors"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, level, message, request_id, Path, StatusCode | filter level = \"ERROR\" | sort @timestamp desc | limit 20"
        }
      },
    ]
  }

  application_dashboard = {
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# 8Byte ${var.environment} - application\nRequest rate, errors, latency, database health, and recent logs."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "Application requests"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.app_requests]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "Application 5xx"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.app_errors]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "Application average latency"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.app_latency]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title   = "Application latency percentiles"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.app_p50, local.app_p90, local.app_p99]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title   = "Application error rate"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = local.app_error_rate
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "ALB requests"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_requests]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "ALB target 5xx"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_target_5xx, local.alb_elb_5xx]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 14
        width  = 8
        height = 6
        properties = {
          title   = "ALB p95 latency"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.alb_latency]
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 20
        width  = 12
        height = 8
        properties = {
          title  = "Top paths"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields Path, Latency | filter ispresent(Path) | stats count() as Requests, avg(Latency) as AvgLatency by Path | sort Requests desc | limit 10"
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 20
        width  = 12
        height = 8
        properties = {
          title  = "Recent errors"
          region = var.aws_region
          view   = "table"
          query  = "SOURCE '${aws_cloudwatch_log_group.app.name}' | fields @timestamp, level, message, request_id, Path, StatusCode | filter level = \"ERROR\" | sort @timestamp desc | limit 20"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 28
        width  = 12
        height = 6
        properties = {
          title   = "RDS CPU and connections"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_cpu, local.rds_conns]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 28
        width  = 12
        height = 6
        properties = {
          title   = "RDS storage and memory"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 60
          metrics = [local.rds_storage, local.rds_memory]
        }
      },
    ]
  }
}

resource "aws_cloudwatch_dashboard" "infrastructure" {
  dashboard_name = "${local.name_prefix}-infrastructure"
  dashboard_body = jsonencode(local.infrastructure_dashboard)
}

resource "aws_cloudwatch_dashboard" "application" {
  dashboard_name = "${local.name_prefix}-application"
  dashboard_body = jsonencode(local.application_dashboard)
}
