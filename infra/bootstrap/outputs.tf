output "state_bucket" {
  description = "S3 bucket used by the Terraform S3 backend."
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table" {
  description = "DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.tf_lock.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = try(aws_iam_openid_connect_provider.github[0].arn, null)
}
