# 8Byte.ai DevOps Assignment Submission

**Candidate:** Pankaj Sharma  
**Email:** pankajsharma98930@gmail.com

## Links

| Item | Link |
|---|---|
| GitHub repository | <https://github.com/pnkjshrma99/8byte-devops-assignment> |
| Loom walkthrough | <https://www.loom.com/share/7b6aa8291c5b4f4eb83138c9e79c3f53> |
| README | <https://github.com/pnkjshrma99/8byte-devops-assignment/blob/main/README.md> |
| Challenges PDF | <https://github.com/pnkjshrma99/8byte-devops-assignment/blob/main/challenges/Challenges.pdf> |
| Challenges Word | <https://github.com/pnkjshrma99/8byte-devops-assignment/blob/main/challenges/Challenges.docx> |

The repository is public. The Loom video is shared as **Anyone with the link
can view**.

## What is included

- Terraform: VPC with public/private subnets, ALB, ECS Fargate, private RDS
  PostgreSQL, security groups, Secrets Manager, S3/DynamoDB state backend, and
  GitHub OIDC.
- CI/CD: pull-request tests, PostgreSQL integration tests, Ruff, Bandit,
  pip-audit, Trivy, Terraform validation, immutable image tags, staging deploy,
  smoke test, and a protected production environment with a required reviewer.
- Observability: CloudWatch infrastructure and application dashboards,
  application JSON/EMF logs, VPC flow logs, ALB access logs, and RDS log export.
- Documentation: architecture decisions, runbook, challenges, cost notes, and a
  Loom walkthrough.

## Verification

- 12 unit tests passed with 80% coverage.
- PostgreSQL integration test passed locally against Docker Compose.
- Docker image built successfully; Trivy critical scan reported zero critical
  vulnerabilities.
- `ruff`, `pip-audit`, `bandit`, `hadolint`, `shellcheck`, `actionlint`, and
  `terraform validate` are clean.
- The GitHub Actions checks pass on `main`.

## Deployment status

Terraform was formatted and validated locally. AWS resources were **not created**
for this submission, so the deployment jobs in the workflow are intentionally
gated on AWS OIDC/ECS variables and are skipped with a notice. The Loom video
demonstrates the local Docker application, Terraform validation, and the CI
checks. No live AWS deployment is claimed.
