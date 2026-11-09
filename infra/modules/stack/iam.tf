data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${local.name_prefix}-ecs-execution"
  description        = "Pull the app image and read runtime secrets"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${local.name_prefix}-ecs-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.db.arn]
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.name_prefix}-ecs-task"
  description        = "Runtime role for the application task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "ecs_exec" {
  count = var.enable_ecs_exec ? 1 : 0

  name = "${local.name_prefix}-ecs-exec"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:StartSession"]
      Resource = [
        "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task/${local.cluster_name}/*",
        "arn:aws:ssm:${var.aws_region}::document/AmazonECS-ExecuteInteractiveCommand",
      ]
    }]
  })
}

# GitHub Actions OIDC deployment role ---------------------------------------

resource "aws_iam_role" "github_deploy" {
  count = local.github_deploy_role_enabled ? 1 : 0

  name        = "${local.name_prefix}-github-deploy"
  description = "GitHub Actions OIDC role for ${var.environment} deployments"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.github_subject
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "github_deploy" {
  count = length(aws_iam_role.github_deploy)

  name = "${local.name_prefix}-github-deploy"
  role = aws_iam_role.github_deploy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = [aws_ecr_repository.app.arn]
      },
      {
        Sid      = "EcsTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        Sid      = "EcsService"
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:TagResource"]
        Resource = ["arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"]
      },
      {
        Sid      = "EcsRead"
        Effect   = "Allow"
        Action   = ["ecs:DescribeClusters", "ecs:DescribeTasks", "ecs:ListTasks"]
        Resource = "*"
      },
      {
        Sid      = "PassTaskRoles"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [aws_iam_role.ecs_execution.arn, aws_iam_role.ecs_task.arn]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      {
        Sid      = "ReadDeploymentLogs"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogStreams", "logs:GetLogEvents"]
        Resource = ["${aws_cloudwatch_log_group.app.arn}:*"]
      },
    ]
  })
}
