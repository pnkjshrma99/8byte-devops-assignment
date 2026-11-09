# 8Byte.ai DevOps Assignment

A production-minded reference implementation of the 8Byte.ai DevOps take-home
assignment: a small PostgreSQL-backed API running on ECS Fargate behind an
Application Load Balancer, provisioned with Terraform and delivered through
GitHub Actions with security scanning, staged rollout, and a manual production
approval gate.

The application logic is intentionally small. The focus is on infrastructure,
automation, observability, security, and the operational decisions behind them.

> **Local verification:** 12 unit tests (80% coverage) and the PostgreSQL
> integration test pass; `ruff`, `pip-audit`, `bandit`, `hadolint`,
> `shellcheck`, `actionlint`, and `terraform validate` are clean. The Docker
> image builds, the Trivy critical scan is clean, and the Compose stack
> (app + PostgreSQL) passed the HTTP smoke test locally. AWS resources are
> designed but were not created in this workspace.

---

## Contents

- [Architecture](#architecture)
- [Requirement mapping](#requirement-mapping)
- [Repository layout](#repository-layout)
- [Run locally](#run-locally)
- [Deploy to AWS](#deploy-to-aws)
- [CI/CD setup](#cicd-setup)
- [Monitoring and logging](#monitoring-and-logging)
- [Security considerations](#security-considerations)
- [Cost optimization](#cost-optimization)
- [Backups and disaster recovery](#backups-and-disaster-recovery)
- [Architecture decisions](#architecture-decisions)
- [Verification performed](#verification-performed)
- [Assumptions and trade-offs](#assumptions-and-trade-offs)
- [What I would add next](#what-i-would-add-next)
- [Cleanup](#cleanup)

---

## Architecture

```mermaid
flowchart TB
    U[Internet] --> R53[Route 53 optional]
    R53 --> ALB[Application Load Balancer<br/>public subnets]
    ALB --> ECS[ECS Fargate service<br/>private app subnets]
    ECS --> RDS[(RDS PostgreSQL<br/>private DB subnets)]
    ECS --> SM[Secrets Manager]
    ECS --> CW[CloudWatch Logs<br/>JSON + EMF metrics]
    ALB --> S3[S3 ALB access logs]
    VPC[VPC flow logs] --> CW
    CW --> D1[Infrastructure dashboard]
    CW --> D2[Application dashboard]
    CW --> ALARMS[CloudWatch alarms] --> SNS[SNS email]
    GHA[GitHub Actions] -->|OIDC, no static keys| ECR[ECR]
    GHA -->|Register task definition| ECS
    ECR --> ECS
```

Traffic path: Route 53 (optional) -> internet-facing ALB -> ECS Fargate tasks in
private subnets -> RDS PostgreSQL in isolated database subnets. Tasks reach AWS
APIs through NAT gateways and an S3 gateway endpoint. No database or application
task has a public IP.

The Terraform stack is split into a shared bootstrap layer and one stateful root
per environment. Both environment roots call the same `modules/stack`, so
staging and production cannot drift structurally.

---

## Requirement mapping

| Assignment requirement | Implementation |
|---|---|
| Part 1: VPC with public/private subnets | `infra/modules/stack/vpc.tf`: 2 AZs by default, public ALB subnets, private app subnets, isolated DB subnets, IGW, NAT, route tables, S3 gateway endpoint, VPC flow logs |
| Part 1: EC2/ECS/EKS hosting | ECS Fargate cluster, task definition, service, autoscaling in `ecs.tf` |
| Part 1: RDS PostgreSQL | `rds.tf`: private subnet group, gp3 encryption, backups, parameter group, optional Multi-AZ and Performance Insights |
| Part 1: Security groups | `security-groups.tf`: ALB -> ECS -> RDS only; RDS has no egress |
| Part 1: Load balancer | `alb.tf`: internet-facing ALB, target group, optional HTTPS redirect and ACM certificate |
| Part 1: `variables.tf` | Root variables plus module variables; environment values live in `terraform.tfvars` |
| Part 1: State management | S3 backend with versioning/encryption + DynamoDB lock table, created in `infra/bootstrap` |
| Part 1: Outputs | `infra/modules/stack/outputs.tf` and environment outputs |
| Part 2: Tests on PR | Unit tests, PostgreSQL integration tests, Ruff, Bandit, pip-audit, Trivy, Terraform format/validate |
| Part 2: Build/push on main | Docker multi-stage build, immutable `sha-<commit>-<run_id>-<run_attempt>` tag, ECR push |
| Part 2: Deploy staging | New ECS task definition revision, `services-stable` wait, HTTP smoke test |
| Part 2: Manual production approval | GitHub `production` environment with required reviewers; separate OIDC role |
| Part 2: Vulnerability scanning | Trivy filesystem/config/image scans; pip-audit blocks known dependency vulnerabilities; critical image vulnerabilities block the pipeline |
| Part 2: Failure notifications | Slack webhook job on any failed pipeline |
| Part 3: Infrastructure metrics | CloudWatch ALB, ECS and RDS metrics |
| Part 3: Application metrics | Request count, 5xx count, client errors and latency emitted by the app as CloudWatch EMF |
| Part 3: Database metrics | RDS CPU, storage, connections, memory, IOPS |
| Part 3: Centralized logging | Application JSON logs, VPC flow logs, ALB access logs in S3, RDS PostgreSQL export |
| Part 3: Two dashboards | `${project}-${env}-infrastructure` and `${project}-${env}-application` |
| Part 4: README | This document |
| Part 4: Secret management | Secrets Manager JSON secret, ECS `secrets` injection, no passwords in code or task definitions |
| Part 4: Backup strategy | RDS automated backups/PITR, production final snapshot, versioned Terraform state, log retention |

---

## Repository layout

```text
.
├── app/                         Flask API, tests, Dockerfile
│   ├── app/                     application package
│   ├── tests/                   unit + PostgreSQL integration tests
│   ├── Dockerfile               multi-stage, non-root runtime
│   └── requirements*.txt
├── infra/
│   ├── bootstrap/               S3 state bucket, DynamoDB lock table, GitHub OIDC provider
│   ├── environments/
│   │   ├── staging/             staging root + backend + tfvars
│   │   └── production/          production root + backend + tfvars
│   ├── modules/stack/           shared VPC, ALB, ECS, RDS, IAM, logging, monitoring
│   └── backend/                 backend config examples
├── scripts/
│   ├── deploy.sh                register/update ECS task definition and wait
│   ├── render-task-def.sh       jq-based image/APP_VERSION update
│   └── smoke-test.sh            health + CRUD smoke test
├── docs/
│   ├── runbook.md               operational procedures
│   ├── architecture.md          deeper request/operations flow
│   ├── roadmap.md               extra-credit ideas
│   └── adr/                     architecture decision records
├── .github/workflows/ci-cd.yml  PR checks, build, deploy, approval, notify
├── docker-compose.yml           local app + PostgreSQL
├── CHALLENGES.md                challenges and resolutions
├── LOOM_SCRIPT.md               demo recording plan
└── README.md
```

---

## Run locally

### Option A: Docker Compose (recommended)

Prerequisites: Docker Desktop or another Docker engine.

```bash
docker compose up --build
```

Then:

```bash
curl -s http://localhost:8000/health/ready
curl -s -X POST http://localhost:8000/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"first item","description":"hello"}'
curl -s http://localhost:8000/api/items
curl -s http://localhost:8000/metrics | head
```

Open `http://localhost:8000/` for service metadata. Application logs are JSON on
stdout; a request log includes a CloudWatch EMF block with `RequestCount`,
`ErrorCount`, `ClientErrorCount`, and `Latency`.

### Option B: Local Python + SQLite

Python 3.9+ is supported locally; the container uses Python 3.12.

```bash
python3 -m venv .venv
.venv/bin/pip install -r app/requirements-dev.txt

cd app
DATABASE_URL=sqlite:////tmp/8byte-local.db \
  ../.venv/bin/python -m app.init_db

DATABASE_URL=sqlite:////tmp/8byte-local.db \
APP_ENV=local APP_VERSION=local \
  ../.venv/bin/gunicorn --config gunicorn.conf.py "app:create_app()"
```

In another terminal:

```bash
./scripts/smoke-test.sh http://localhost:8000
```

### Tests

```bash
make test          # Ruff + unit tests + coverage gate
make test-integration  # requires TEST_DATABASE_URL
```

Integration tests intentionally refuse to run unless the URL contains `test`, to
avoid dropping a real schema by accident.

---

## Deploy to AWS

### Prerequisites

- AWS account and credentials with permission to create VPC, ECS, RDS, IAM,
  CloudWatch, S3, and DynamoDB resources
- Terraform >= 1.6 (the repo was validated with 1.17.1)
- AWS CLI v2
- Docker
- A GitHub repository with Actions enabled
- Optional: a Route 53 hosted zone and domain for TLS

### Step 1: Bootstrap shared state and OIDC

```bash
cd infra/bootstrap
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output
```

This creates:

- S3 state bucket with versioning, SSE-S3, public-access block, and a
  deny-insecure-transport policy
- DynamoDB lock table with PITR and encryption
- GitHub Actions OIDC provider (set `create_github_oidc_provider = false` if the
  account already has one)

The bootstrap root uses local state because it creates the backend it would
otherwise need. Back up `infra/bootstrap/terraform.tfstate` securely.

### Step 2: Configure the environment backend

Create the backend files (they are gitignored) and substitute the account ID
printed by the bootstrap output:

```bash
cp infra/backend/staging.hcl.example infra/backend/staging.hcl
cp infra/backend/production.hcl.example infra/backend/production.hcl
```

The bucket name is `8byte-tfstate-<ACCOUNT_ID>-ap-south-1`; the lock table is
`8byte-tf-lock`.

### Step 3: Set environment values

Edit `infra/environments/staging/terraform.tfvars` and
`infra/environments/production/terraform.tfvars`:

- `github_repository` must match the real `owner/repo`; it is used in the OIDC
  trust policy.
- `alarm_email` receives CloudWatch alarms. SNS sends a confirmation email.
- For HTTPS, set `domain_name`, `hosted_zone_id`, and either
  `create_acm_certificate = true` or an existing `acm_certificate_arn`.
  The default is HTTP-only so the stack can be evaluated without owning a domain.
- Production defaults to Multi-AZ RDS, deletion protection, 14-day backups, two
  NAT gateways, and no Fargate Spot. Staging uses one NAT gateway, Fargate Spot,
  and a single-AZ micro RDS instance.

### Step 4: Apply staging

```bash
cd infra/environments/staging
terraform init -backend-config=../../backend/staging.hcl
terraform plan -out=staging.tfplan
terraform apply staging.tfplan

terraform output
```

The first apply starts a tiny public bootstrap container so the ALB target group
becomes healthy before the real image exists. The first CI deployment replaces
it with the application image and removes the placeholder command. This avoids a
chicken-and-egg problem between ECR, ECS, and the first build.

Apply production the same way with its backend and tfvars.

### Step 5: Create and connect the GitHub repository

```bash
git init
git add .
git commit -m "Add 8Byte DevOps assignment"
gh repo create <owner>/8byte-devops-assignment --private --source=. --remote=origin --push
```

Configure repository variables (Settings -> Secrets and variables -> Actions ->
Variables). Values come from `terraform output`:

| Variable | Source |
|---|---|
| `AWS_REGION` | `ap-south-1` |
| `AWS_ROLE_ARN_STAGING` | staging `github_deploy_role_arn` |
| `AWS_ROLE_ARN_PRODUCTION` | production `github_deploy_role_arn` |
| `ECR_REPOSITORY_STAGING` | staging `ecr_repository_url` |
| `ECR_REPOSITORY_PRODUCTION` | production `ecr_repository_url` |
| `ECS_CLUSTER_STAGING` | staging `ecs_cluster_name` |
| `ECS_SERVICE_STAGING` | staging `ecs_service_name` |
| `TASK_FAMILY_STAGING` | staging `task_definition_family` |
| `STAGING_URL` | staging `app_url` |
| `ECS_CLUSTER_PRODUCTION` | production `ecs_cluster_name` |
| `ECS_SERVICE_PRODUCTION` | production `ecs_service_name` |
| `TASK_FAMILY_PRODUCTION` | production `task_definition_family` |
| `PRODUCTION_URL` | production `app_url` |

Add secret `SLACK_WEBHOOK_URL` for failure notifications.

Create two GitHub Environments:

- `staging`: restrict deployment branches to `main`.
- `production`: restrict deployment branches to `main` and add required
  reviewers. This is the manual approval gate; no separate approval action is
  needed.

Enable branch protection on `main`: require pull request, require the `Unit
tests and lint`, `Integration tests (PostgreSQL)`, and `Security and IaC checks`
checks, and disallow bypass.

### Step 6: Deploy

Push to `main` (or run the workflow after a PR merge). The pipeline:

1. Runs unit and integration tests, lint, security scans, and Terraform
   validation.
2. Builds and pushes the staging image with an immutable
   `sha-<commit>-<run_id>-<run_attempt>` tag.
3. Scans the image for critical vulnerabilities.
4. Registers a new ECS task definition, updates staging, waits for stability, and
   runs the smoke test.
5. Waits for production approval in the `production` environment.
6. Builds/pushes the approved commit to the production ECR repository, scans it,
   deploys production, and runs the smoke test.
7. Sends a Slack notification if any job fails.

The pipeline uses GitHub OIDC. No AWS access keys are stored in GitHub.

### Step 7: Verify

```bash
curl -s "$(terraform -chdir=infra/environments/staging output -raw app_url)/health/ready"
```

Open the two dashboard URLs from `terraform output`, and inspect logs:

```bash
aws logs tail /aws/ecs/8byte-staging/app --follow
```

---

## CI/CD setup

### Pull requests

- Ruff
- Unit tests with coverage gate
- PostgreSQL integration tests using a service container
- pip-audit dependency audit (blocks on known vulnerabilities)
- Bandit static analysis
- Trivy filesystem and Terraform misconfiguration scans
- Terraform `fmt` and `validate` for both environment roots

### Main branch

- Build and push to staging ECR with a commit SHA tag
- Trivy image scan; critical, fixable vulnerabilities fail the build
- Deploy staging and run the smoke test
- Manual production approval
- Build/push the same commit to production ECR, scan, deploy, smoke test
- Slack notification on failure

The image tag is immutable (ECR tag mutability is `IMMUTABLE`), and the ECR
lifecycle policy expires untagged images after 7 days and keeps the last 30
`sha-` images.

### Why OIDC instead of access keys

Each environment has its own IAM role trusted only for
`repo:<owner>/<repo>:environment:<environment>`. The production role can only be
assumed by a job that has passed the `production` environment's protection rules.
The roles can push/pull a single ECR repository, register task definitions, update
one ECS service, pass only the ECS task roles, and read that service's log group.

---

## Monitoring and logging

### Dashboards

**Infrastructure** (`8byte-<env>-infrastructure`):

- ALB request count, target/ELB 5xx, p95 latency
- Healthy/unhealthy target counts
- ECS running/desired tasks, CPU, memory
- RDS CPU, free storage, connections, read/write IOPS
- Recent application errors from Logs Insights

**Application** (`8byte-<env>-application`):

- Request count, 5xx count, average latency
- p50/p90/p99 latency
- Error-rate metric math
- ALB request/5xx/latency cross-check
- Top paths and recent errors from Logs Insights
- RDS CPU, connections, storage and memory

The application emits EMF metrics to stdout, so CloudWatch extracts them from
the log stream without a sidecar or agent. The namespace is `8Byte/App` with
dimensions `Service` and `Environment`. Prometheus `/metrics` is also exposed for
local debugging and future ADOT/Prometheus integration.

### Alarms

CloudWatch alarms publish to an SNS topic; set `alarm_email` to receive email.
The stack creates alarms for:

- ALB target 5xx and ALB-generated 5xx
- ALB p95 latency
- Unhealthy targets
- ECS CPU and memory
- RDS CPU, free storage, and connection count
- Application 5xx count and p99 latency

All alarms have `ok_actions`, so recovery is visible. Missing data is treated as
`notBreaching` except for unhealthy hosts, where it is `breaching`.

### Log sources

| Source | Destination | Retention |
|---|---|---|
| Application stdout (JSON + EMF) | CloudWatch Logs `/aws/ecs/<env>/app` | 30d staging, 90d prod |
| VPC flow logs | CloudWatch Logs `/aws/vpc/<env>/flow-logs` | same as log retention |
| ALB access logs | S3 bucket with lifecycle expiration | 30d staging, 90d prod |
| RDS PostgreSQL/upgrade logs | CloudWatch Logs (RDS export) | RDS-managed; tune in console |
| ECS Container Insights | CloudWatch Logs/metrics | service-managed |

Useful Logs Insights queries:

```sql
-- recent errors
SOURCE '/aws/ecs/8byte-staging/app'
| fields @timestamp, level, message, request_id, Path, StatusCode
| filter level = "ERROR"
| sort @timestamp desc
| limit 20

-- slowest paths
SOURCE '/aws/ecs/8byte-staging/app'
| fields Path, Latency, StatusCode
| filter ispresent(Path)
| stats avg(Latency) as avg_ms, pct(Latency, 99) as p99_ms, count() as requests by Path
| sort p99_ms desc
```

---

## Security considerations

**Network**

- ALB is the only internet-facing component.
- ECS tasks and RDS are in private subnets with no public IP.
- Security groups allow only ALB -> app port and app -> PostgreSQL. RDS has no
  egress rules.
- Public subnets do not auto-assign public IPs.
- VPC flow logs capture accepted and rejected traffic.

**Identity and access**

- GitHub Actions uses OIDC with per-environment roles and a subject condition.
- No long-lived AWS access keys are stored in GitHub.
- ECS execution and task roles are separate.
- The execution role can read only the application secret and pull images.
- The task role has no AWS permissions by default; ECS Exec is opt-in.
- Production deploys require a protected GitHub environment.

**Data and secrets**

- RDS storage is encrypted; backups inherit encryption.
- Database credentials and the Flask secret key are generated by Terraform,
  stored in Secrets Manager, and injected into ECS at runtime.
- No password is written to Terraform outputs or task definition JSON.
- RDS is not publicly accessible and has deletion protection in production.
- TLS is available via ACM and ALB HTTPS redirect; production should set a
  domain/certificate before real traffic.

**Supply chain and runtime**

- ECR image tags are immutable; images are scanned on push and in CI.
- Trivy scans the filesystem, Terraform, and the built image.
- pip-audit and Bandit run in CI.
- The container runs as UID 10001, not root.
- Gunicorn runs with one worker and four threads for predictable memory; the app
  is I/O-bound and ECS scales horizontally.
- ALB drops invalid headers and uses defensive desync mitigation.
- S3 buckets block public access and deny insecure transport.

**Deliberate gaps / next steps**

- WAF, Shield Advanced, GuardDuty, Security Hub, and AWS Config are account-level
  controls and are not included in this app stack.
- Use a customer-managed KMS key for Secrets Manager, RDS, and logs in a real
  regulated environment.
- Add Secrets Manager rotation (Lambda) and RDS Proxy if connection churn grows.
- Add image signing (cosign) and SBOM attestations.
- Add private ECR/Secrets Manager/CloudWatch Logs VPC endpoints to remove the
  broad HTTPS egress rule and reduce NAT data cost.

---

## Cost optimization

- **Staging:** one NAT gateway, Fargate Spot, one small task, `db.t4g.micro`,
  single-AZ RDS, 30-day logs. Good for demos; not HA.
- **Production:** two NAT gateways, on-demand Fargate, Multi-AZ RDS, deletion
  protection, longer retention. This is the availability/cost trade-off.
- **Compute:** target-tracking autoscaling on CPU and memory; desired count is
  managed by autoscaling after creation.
- **Storage:** gp3 RDS storage with autoscaling to 100 GiB; ECR lifecycle policy;
  S3 lifecycle expiration; CloudWatch log retention.
- **No idle EKS control plane:** ECS Fargate avoids a fixed cluster fee and
  node-group management for a small service.
- **Destroy staging when idle.** The production stack should stay up, but staging
  can be recreated from code. RDS final snapshots are skipped in staging by
  default.

Ballpark staging cost while running: ALB, one NAT gateway, one small Fargate
task, and a micro RDS instance typically land around USD 80-150 per month in
`ap-south-1` depending on data transfer, log volume, and LCU usage. Check the AWS
pricing calculator for the account's region before leaving it running.

---

## Backups and disaster recovery

- **RDS automated backups:** 7 days staging, 14 days production, with
  point-in-time recovery. Production keeps a final snapshot on deletion.
- **Restore:** restore to a new instance from a snapshot or PITR, update the
  Secrets Manager host, then deploy a new task definition. The runbook has the
  exact commands.
- **Terraform state:** S3 versioning plus noncurrent-version expiration; DynamoDB
  locking prevents concurrent applies. The bootstrap state is local and should be
  backed up separately.
- **Logs:** ALB logs in versioned S3 with lifecycle expiration; application logs
  in CloudWatch with retention.
- **Improvement:** add AWS Backup with a vault lock and cross-region copy for RDS
  if the recovery objective requires region loss protection.

---

## Architecture decisions

Detailed ADRs live in [`docs/adr`](docs/adr). The short version:

1. **ECS Fargate over EKS/EC2.** The service is small; Fargate removes node
   patching and a fixed control-plane cost while keeping rolling deployments,
   autoscaling, and Container Insights.
2. **One Terraform module, two environment roots.** Separate roots give separate
   state, blast radius, and backend keys without duplicating resource code.
   Workspaces were avoided because a `workspace select` mistake is easy to make.
3. **S3 + DynamoDB backend.** Native S3 locking requires newer Terraform and has
   fewer operational knobs; DynamoDB locking is well understood and auditable.
4. **Secrets Manager + ECS secret injection.** No credentials in task definitions,
   environment files, or Terraform outputs.
5. **CloudWatch EMF over a sidecar.** One less container, no Prometheus server to
   operate, and application metrics arrive in the same log stream as the request.
6. **GitHub OIDC over static keys.** Short-lived credentials, per-environment
   roles, and a hard link to GitHub's protected environment.
7. **Bootstrap placeholder image.** ECS needs an image before ECR has one. A tiny
   public Python HTTP server keeps the ALB healthy during the first apply; CI
   replaces it with the real image and removes the command override.

---

## Verification performed

```text
$ cd app && python -m pytest -m "not integration"
12 passed, 1 deselected

Coverage: 80% (gate: 70%)

$ TEST_DATABASE_URL=postgresql+psycopg://app:app@localhost:5432/app_test \
    python -m pytest -m integration
1 passed, 12 deselected

$ ruff check app tests
All checks passed!

$ pip-audit -r app/requirements.txt
No known vulnerabilities found

$ bandit -r app/app -q -ll
(clean)

$ terraform fmt -check -recursive infra
(clean)

$ terraform -chdir=infra/environments/staging validate
Success! The configuration is valid.

$ terraform -chdir=infra/environments/production validate
Success! The configuration is valid.

$ hadolint app/Dockerfile
(clean)

$ actionlint .github/workflows/ci-cd.yml
$ shellcheck scripts/*.sh app/entrypoint.sh
(clean)

$ docker build -t 8byte-app:local ./app
Successfully built 8byte-app:local

$ docker compose up -d --build
$ ./scripts/smoke-test.sh http://127.0.0.1:8000
smoke test passed against http://127.0.0.1:8000
```

A local Gunicorn + SQLite run verified `/`, `/health/live`, `/health/ready`,
`/api/items` CRUD, `/metrics`, request IDs, JSON logs, and the EMF payload. A
Docker Compose run with PostgreSQL verified the multi-stage image build, the
entrypoint's schema bootstrap, container health checks, CRUD, JSON/EMF logs, and
the smoke test. The PostgreSQL integration test also passed against the Compose
database.

Terraform was formatted and validated locally, but it was not planned or applied
against an AWS account. AWS deployment, GitHub Actions execution, and the Loom
recording remain for the reviewer/author to perform.

---

## Assumptions and trade-offs

- The app uses `db.create_all()` on startup for a fast demo. A real service should
  use Alembic migrations or a dedicated migration task before the ECS rollout.
- The bootstrap image is a public Python image; production deployments replace it
  immediately. If the account blocks public ECR/Docker Hub pulls, set
  `app_image` to an internal bootstrap image.
- Production TLS is opt-in. The default tfvars are HTTP-only so the assignment can
  be evaluated without a domain; a real production launch must add ACM/Route 53.
- One shared account/region is assumed. Multi-account landing zones, SCPs, and
  centralized logging are out of scope.
- The app has no authentication. The sample API is intentionally anonymous; put
  Cognito or an API gateway in front before exposing real data.
- Terraform applies are performed by a privileged human/CI role. The app delivery
  pipeline uses narrowly scoped OIDC roles and does not run `terraform apply`.
  Infra changes should go through a reviewed plan.
- CloudWatch metrics are the source of truth for alarms. Prometheus `/metrics` is
  available for local development but is not scraped in AWS.

---

## What I would add next

See [`docs/roadmap.md`](docs/roadmap.md) for the full list. High-value additions:

- Alembic migration task in the deployment pipeline
- AWS WAF rate limiting and managed rule groups
- Secrets Manager rotation Lambda
- RDS Proxy for connection pooling
- Blue/green deployment with CodeDeploy and automatic rollback
- AWS Backup cross-region copies and restore drills
- Terraform plan on PR using a read-only OIDC role and protected state access
- ECS Exec audit trail / Session Manager logging
- OpenTelemetry traces and SLO burn-rate alarms
- Cost budgets, AWS Config conformance packs, and drift detection

---

## Cleanup

Destroy environments in reverse order. Production has deletion protection and a
final RDS snapshot by default; disable those intentionally before destroying.

```bash
cd infra/environments/production
terraform init -backend-config=../../backend/production.hcl
terraform destroy

cd ../staging
terraform init -backend-config=../../backend/staging.hcl
terraform destroy

cd ../../bootstrap
terraform destroy
```

If the state bucket contains objects, empty it only after confirming no other
environment state lives there. `force_destroy` is intentionally false.

---

## Submission links

- GitHub repository: <https://github.com/pnkjshrma99/8byte-devops-assignment>
  (private by default; make it public or invite the reviewer before submission)
- Challenges document: [`challenges/Challenges.pdf`](challenges/Challenges.pdf)
  and [`challenges/Challenges.docx`](challenges/Challenges.docx)
- Loom walkthrough: add the Loom URL after recording; script in
  [`LOOM_SCRIPT.md`](LOOM_SCRIPT.md)
