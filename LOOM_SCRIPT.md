# Loom Walkthrough Script

Target length: 7–9 minutes. Record the terminal and browser side by side. Keep the
AWS console tabs open before recording if the stack is deployed; otherwise use the
local demo and the code walkthrough fallback at the end.

## Before recording

```bash
cd /Users/macos/projects/8byte
make test
terraform -chdir=infra/environments/staging validate
```

If the AWS stack is deployed, have these ready:

- CloudWatch infrastructure dashboard
- CloudWatch application dashboard
- ECS service events / task logs
- GitHub Actions run showing the production approval gate

If AWS is not deployed, run the local demo:

```bash
docker compose up --build
# or, without Docker:
cd app
DATABASE_URL=sqlite:////tmp/8byte-demo.db ../.venv/bin/python -m app.init_db
DATABASE_URL=sqlite:////tmp/8byte-demo.db APP_ENV=local APP_VERSION=demo \
  ../.venv/bin/gunicorn --config gunicorn.conf.py "app:create_app()"
```

## 0:00 — 0:40 Introduction

> "This is my 8Byte DevOps assignment. The application is deliberately small: a
> Flask CRUD API backed by PostgreSQL. The focus is the platform around it:
> Terraform-provisioned VPC, ECS Fargate, RDS, ALB, secrets, CloudWatch
> observability, and a GitHub Actions pipeline with a manual production gate."

Show the repository tree briefly.

## 0:40 — 2:15 Infrastructure walkthrough

Open `infra/modules/stack/vpc.tf`, `security-groups.tf`, `alb.tf`, `ecs.tf`,
`rds.tf`, `secrets.tf`.

Talking points:

- VPC with public ALB subnets, private app subnets, isolated DB subnets, one NAT
  per AZ in production and one NAT in staging.
- Security groups: ALB -> app, app -> RDS; RDS has no egress. No public IPs on
  tasks or database.
- ECS Fargate, Container Insights, autoscaling on CPU/memory, deployment circuit
  breaker.
- RDS PostgreSQL: private subnet group, gp3 encryption, automated backups,
  parameter group, optional Multi-AZ/Performance Insights.
- Secrets Manager JSON secret; ECS injects `DB_USER`, `DB_PASSWORD`, and
  `SECRET_KEY`; nothing sensitive is in the task definition.
- Bootstrap image explains the first-apply chicken-and-egg problem and how CI
  replaces it.

Open `infra/bootstrap` and show S3/DynamoDB state + OIDC provider. Mention separate
environment roots and backend keys.

## 2:15 — 3:15 Terraform validation / plan

```bash
terraform fmt -check -recursive infra
terraform -chdir=infra/environments/staging validate
```

> "Both environment roots call the same module but have separate state keys, so a
> staging apply cannot touch production state. The backend uses S3 versioning and a
> DynamoDB lock table."

If a plan is available, show the resource count and call out that the first apply
uses the bootstrap image.

## 3:15 — 4:30 Local application demo

```bash
curl -s http://localhost:8000/health/ready
curl -s -X POST http://localhost:8000/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"loom","description":"demo"}'
curl -s http://localhost:8000/api/items
curl -s http://localhost:8000/metrics | head
```

Show a JSON log line with `_aws` at the root.

> "Every request produces structured JSON with a request ID and an EMF block.
> CloudWatch extracts RequestCount, ErrorCount, ClientErrorCount, and Latency
> without a sidecar. The same request ID is in the log and the response header."

Show `Duration`/latency and `Path`/`StatusCode` fields. Mention `/health/live` vs
`/health/ready`: ECS uses liveness, ALB uses readiness so a database startup does
not cause a restart loop.

## 4:30 — 5:45 CI/CD walkthrough

Open `.github/workflows/ci-cd.yml`.

Talking points:

- PR: Ruff, unit tests with coverage gate, PostgreSQL integration tests, pip-audit,
  Bandit, Trivy filesystem/Terraform, Terraform validate.
- Main: build/push immutable `sha-<commit>`, Trivy image scan, ECS deploy, wait
  `services-stable`, smoke test.
- Production: GitHub Environment with required reviewers; separate OIDC role whose
  trust is scoped to `environment:production`. No static AWS keys.
- Failure: Slack webhook.
- `scripts/deploy.sh` registers a new task definition from the latest family,
  updates the image and `APP_VERSION`, removes the bootstrap command, and waits.

If a run is available, show the staging job and the production "Review pending"
state. Do not approve it on camera unless you intend to deploy.

## 5:45 — 7:00 Monitoring and logging

Open the two CloudWatch dashboards.

Infrastructure:

> "ALB requests/5xx/latency, healthy and unhealthy targets, ECS CPU/memory/task
> count, RDS CPU/storage/connections/IOPS. The dashboard includes a Logs Insights
> widget for recent errors."

Application:

> "Custom EMF request/error/latency, p50/p90/p99, error-rate metric math, top paths,
> and correlated RDS health."

Open one alarm and show the SNS action. Mention:

- app logs in `/aws/ecs/<env>/app`
- VPC flow logs in CloudWatch
- ALB access logs in S3 with lifecycle expiration
- RDS PostgreSQL/upgrade log export
- retention: 30 days staging, 90 days production

Run a Logs Insights query if the stack is live:

```sql
SOURCE '/aws/ecs/8byte-staging/app'
| fields @timestamp, level, request_id, Path, StatusCode, Latency
| filter ErrorCount = 1
| sort @timestamp desc
| limit 20
```

## 7:00 — 8:00 Security, cost, and challenges

Talking points:

- Private tasks/database, least-privilege security groups, no public DB.
- Secrets Manager injection, encrypted RDS/state/logs buckets, immutable ECR tags,
  non-root container, Trivy/pip-audit/Bandit.
- GitHub OIDC per environment; production approval.
- Cost: staging single NAT + Fargate Spot + micro RDS; production Multi-AZ + NAT per
  AZ + longer retention. Destroy staging when idle.
- Challenges: bootstrap image chicken-and-egg, ACM set indexing, ECS service ARN,
  security-group cycle, OIDC environment subject, EMF root placement, RDS version
  drift. See `CHALLENGES.md`.

## 8:00 — 8:30 Close

> "The happy path is end-to-end: PR checks, immutable image, staging deploy, smoke
> test, manual approval, production deploy, dashboards and alarms. The README lists
> the trade-offs and the next improvements: Alembic migrations, WAF, secret
> rotation, RDS Proxy, signed artifact promotion, and Terraform plan on PR."

## Fallback if AWS is not deployed

Be explicit: "I validated Terraform locally and did not create AWS resources in this
recording." Show:

1. `terraform validate` output.
2. The dashboard JSON in `infra/modules/stack/dashboards.tf`.
3. The local application + logs + `/metrics`.
4. The workflow and scripts.
5. The architecture diagram and README.

Do not claim a live deployment that was not performed. Reviewers value honest
verification over a fabricated console tour.
