# Roadmap and Extra-Credit Ideas

These are deliberately not implemented in the core assignment, to keep the
submission reviewable within the time box. Each item includes why it matters.

## Delivery

- **Alembic migrations as a one-off ECS task** before the service rollout. Remove
  `AUTO_MIGRATE=true` from production.
- **Build once, promote everywhere.** Push to a shared artifact ECR repository,
  sign with cosign, verify the digest in the production job, and deploy by digest
  rather than tag.
- **Terraform plan on PR** with a read-only OIDC role and protected state access.
  Post the plan as a PR comment and require approval for apply.
- **Drift detection** on a schedule (`terraform plan -detailed-exitcode`) with a
  Slack alert.
- **Blue/green deployments** with CodeDeploy, a test listener, and automatic
  rollback based on alarms.

## Reliability

- **SLOs and burn-rate alerts** for availability and latency.
- **Synthetic canary** that exercises `/health/ready` and a CRUD write from
  multiple regions.
- **RDS Proxy** for connection pooling during large ECS scale-out events.
- **AWS Backup** with vault lock and cross-region copy; run a restore drill and
  record RTO/RPO.
- **Multi-AZ staging** or a small shared pre-production environment for
  resilience testing.
- **Graceful shutdown test**: verify the app handles SIGTERM and ALB deregistration
  delay without dropping in-flight requests.

## Security

- **AWS WAF** managed rule groups and rate limiting on the ALB.
- **Customer-managed KMS keys** for RDS, Secrets Manager, CloudWatch Logs, and S3.
- **Secrets Manager rotation** Lambda on a schedule; app reads the latest secret
  version through ECS.
- **Private interface endpoints** for ECR, Secrets Manager, CloudWatch Logs, and
  STS; tighten the ECS egress rule from `0.0.0.0/0:443`.
- **GuardDuty, Security Hub, AWS Config, and SCPs** at the account/org level.
- **Image signing and SBOM** (Syft/Trivy) with admission verification.
- **AuthN/AuthZ** with Cognito or an API gateway before exposing the API.
- **ECS Exec session logging** to CloudWatch/S3 with an audit trail.

## Observability

- **OpenTelemetry traces** from Flask through SQLAlchemy to PostgreSQL; export via
  ADOT to X-Ray or a managed backend.
- **Prometheus/Grafana** as an alternative to CloudWatch for teams already running
  that stack; the app already exposes `/metrics`.
- **Structured audit events** for create/update/delete with actor identity.
- **Dashboard as code in Grafana** if the organization standardizes on Grafana.
- **Log subscription** to a SIEM (Security Lake, Splunk, or OpenSearch).

## Application

- Pagination and filtering on `GET /api/items`.
- Optimistic concurrency / ETags.
- Request size and rate limiting at the app and ALB/WAF layers.
- Database indexes for the actual query patterns.
- Contract tests and API schema (OpenAPI) generation.
- A real frontend only if the assignment scope expands.

## Platform

- Multi-account landing zone (dev/staging/prod) with AWS Organizations.
- Centralized logging and security accounts.
- Terragrunt or a platform pipeline if the number of environments grows.
- Budgets and anomaly detection per environment.
- Cost allocation tags enforced through SCPs.
