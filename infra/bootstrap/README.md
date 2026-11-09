# Bootstrap

This root creates the account-level prerequisites that cannot live in the
environment stacks:

- S3 bucket for Terraform state, with versioning, SSE-S3, public-access block,
  and a deny-insecure-transport policy
- DynamoDB table for state locking
- GitHub Actions OIDC provider (optional; disable if your account already has it)

Because this stack creates the state backend itself, it intentionally uses local
state. Run it once, then move on to `infra/environments/staging` and
`infra/environments/production`.

```bash
cd infra/bootstrap
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan

terraform output state_bucket
terraform output lock_table
```

Copy the bucket and table names into the backend files for each environment.

The bootstrap state contains only the bucket, table, and OIDC provider. Keep a
copy of `terraform.tfstate` somewhere safe (or import the resources later) if you
need to rebuild this layer. The environment stacks use the remote backend.
