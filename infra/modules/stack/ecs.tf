resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.common_tags, { Name = local.cluster_name })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.app_cpu)
  memory                   = tostring(var.app_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    merge(
      {
        name      = local.container_name
        image     = local.app_image
        essential = true

        portMappings = [{
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }]

        environment = [
          { name = "APP_ENV", value = var.environment },
          { name = "APP_VERSION", value = var.app_version },
          { name = "SERVICE_NAME", value = local.service_name },
          { name = "LOG_LEVEL", value = var.log_level },
          { name = "EMF_ENABLED", value = "true" },
          { name = "METRICS_NAMESPACE", value = "8Byte/App" },
          { name = "DB_HOST", value = aws_db_instance.this.address },
          { name = "DB_PORT", value = tostring(aws_db_instance.this.port) },
          { name = "DB_NAME", value = var.db_name },
          { name = "DB_SSLMODE", value = "require" },
          { name = "AUTO_MIGRATE", value = "true" },
          { name = "WEB_CONCURRENCY", value = "1" },
          { name = "WEB_THREADS", value = "4" },
        ]

        secrets = [
          { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.db.arn}:username::" },
          { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db.arn}:password::" },
          { name = "SECRET_KEY", valueFrom = "${aws_secretsmanager_secret.db.arn}:app_secret_key::" },
        ]

        healthCheck = {
          # Python is present in both the bootstrap image and the application
          # image, unlike curl or wget.
          command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.app_port}/health/live', timeout=3)\" || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 30
        }

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.app.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "app"
          }
        }

        stopTimeout = 30
      },
      local.is_bootstrap ? { command = local.bootstrap_command } : {}
    )
  ])

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-app" })
}

resource "aws_ecs_service" "app" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_desired_count

  dynamic "capacity_provider_strategy" {
    for_each = var.app_use_fargate_spot ? [
      { name = "FARGATE", base = 0, weight = 1 },
      { name = "FARGATE_SPOT", base = 0, weight = 3 },
      ] : [
      { name = "FARGATE", base = 0, weight = 1 },
    ]

    content {
      capacity_provider = capacity_provider_strategy.value.name
      base              = capacity_provider_strategy.value.base
      weight            = capacity_provider_strategy.value.weight
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = var.app_desired_count > 1 ? 100 : 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  enable_execute_command             = var.enable_ecs_exec
  platform_version                   = "LATEST"

  network_configuration {
    subnets          = aws_subnet.private_app[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = var.app_port
  }

  lifecycle {
    # CI registers new task definition revisions and autoscaling owns the
    # desired count. Terraform still owns the service and all infrastructure.
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [
    aws_ecs_cluster_capacity_providers.this,
    aws_lb_listener.http_forward,
    aws_lb_listener.https,
    aws_secretsmanager_secret_version.db,
    aws_db_instance.this,
  ]

  tags = merge(local.common_tags, { Name = local.service_name })
}

resource "aws_appautoscaling_target" "ecs" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.app_min_capacity
  max_capacity       = var.app_max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name_prefix}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 65

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${local.name_prefix}-memory"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 75

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
