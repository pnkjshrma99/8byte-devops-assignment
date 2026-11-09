locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  cluster_name   = local.name_prefix
  service_name   = "${var.project_name}-app"
  container_name = "app"
  db_identifier  = "${local.name_prefix}-pg"

  azs                      = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnet_cidrs      = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_app_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  private_db_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  nat_gateway_count = var.single_nat_gateway ? 1 : var.az_count

  tls_enabled     = var.acm_certificate_arn != "" || var.create_acm_certificate
  certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : try(aws_acm_certificate_validation.this[0].certificate_arn, "")
  app_fqdn        = var.domain_name != "" ? var.domain_name : aws_lb.this.dns_name
  app_url         = "${local.tls_enabled ? "https" : "http"}://${local.app_fqdn}"

  is_bootstrap    = var.app_image == ""
  bootstrap_image = "public.ecr.aws/docker/library/python:3.12-alpine"
  app_image       = local.is_bootstrap ? local.bootstrap_image : var.app_image
  bootstrap_command = [
    "python",
    "-c",
    "import http.server as h; H=type('H',(h.BaseHTTPRequestHandler,),{'do_GET':lambda s:(s.send_response(200),s.end_headers(),s.wfile.write(b'ok')),'log_message':lambda *a:None}); h.HTTPServer(('0.0.0.0',8000),H).serve_forever()",
  ]

  db_parameter_group_family = "postgres${split(".", var.db_engine_version)[0]}"
  db_final_snapshot_id      = "${local.name_prefix}-final"

  log_group_name = "/aws/ecs/${local.name_prefix}/app"
  ecr_repo_name  = "${local.name_prefix}/app"

  alb_name = substr("${local.name_prefix}-alb", 0, 32)
  tg_name  = substr("${local.name_prefix}-tg", 0, 32)

  alb_logs_bucket = lower("${var.project_name}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}")

  github_deploy_role_enabled = var.create_github_deploy_role && var.github_repository != ""
  github_subject             = "repo:${var.github_repository}:environment:${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
      Component   = "app"
    },
    var.tags
  )
}
