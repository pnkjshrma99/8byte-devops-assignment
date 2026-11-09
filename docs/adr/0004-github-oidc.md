# ADR 0004: GitHub OIDC with per-environment roles

## Status

Accepted.

## Context

The pipeline needs to push images and update ECS. Storing long-lived AWS access
keys in GitHub secrets is common but creates rotation and exfiltration risk.

## Decision

Use GitHub Actions OpenID Connect with one IAM role per environment. Trust is
restricted to `repo:<owner>/<repo>:environment:<environment>`. The production job
uses a GitHub Environment with required reviewers.

## Consequences

- No static AWS keys in the repository or GitHub secrets.
- Credentials are short-lived and scoped to one repository/environment.
- The trust policy depends on the correct repository name and environment names;
  a rename requires a Terraform change.
- The roles are intentionally narrow: ECR push/pull for one repository, ECS task
  definition registration, one service update, pass only the ECS task roles, and
  read one log group.
- Terraform applies remain a privileged human/CI action, not part of the app
  deployment role.

## Alternatives considered

- **Static IAM user access keys:** simple, but long-lived and hard to audit.
- **Self-hosted runner with an instance profile:** more infrastructure and a larger
  blast radius if the runner is compromised.
- **One shared deploy role:** fewer roles, but no environment separation and a
  production compromise would also expose staging.
