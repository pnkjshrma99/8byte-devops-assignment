variable "project_name" {
  description = "Prefix used for shared platform resources."
  type        = string
  default     = "8byte"
}

variable "aws_region" {
  description = "AWS region for the Terraform state bucket and OIDC provider."
  type        = string
  default     = "ap-south-1"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if it already exists in the account."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to shared resources."
  type        = map(string)
  default     = {}
}
