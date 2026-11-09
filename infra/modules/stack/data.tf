data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  count = local.github_deploy_role_enabled ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}
