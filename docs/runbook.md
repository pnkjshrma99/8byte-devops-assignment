# Runbook

## Deploy a new application image manually

```bash
export AWS_REGION=ap-south-1
export CLUSTER=8byte-staging
export SERVICE=8byte-app
export FAMILY=8byte-staging-app
export IMAGE=<account>.dkr.ecr.ap-south-1.amazonaws.com/8byte-staging/app:sha-<commit>

./scripts/deploy.sh "$CLUSTER" "$SERVICE" "$IMAGE" "$FAMILY" "<commit>"
./scripts/smoke-test.sh "$(terraform -chdir=infra/environments/staging output -raw app_url)"
```

The script reads the latest task definition, updates the image and `APP_VERSION`,
removes any bootstrap `command` override, registers a new revision, updates the
service, and waits for `services-stable`.

## Roll back

Find the previous task definition revision:

```bash
aws ecs list-task-definitions --family-prefix "$FAMILY" --sort DESC --max-items 10
aws ecs describe-task-definition --task-definition "$FAMILY:<revision>" \
  --query 'taskDefinition.containerDefinitions[0].image'
```

Then update the service directly to that revision:

```bash
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$FAMILY:<revision>" \
  --force-new-deployment

aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"
```

The deployment circuit breaker normally performs this rollback automatically if a
new revision cannot become healthy.

## Inspect a failing deployment

```bash
aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" \
  --query 'services[0].events[0:10]'

aws logs tail "/aws/ecs/${CLUSTER}/app" --follow
```

Check the service event stream for `CannotPullContainerError`,
`ResourceInitializationError`, or health-check failures. The most common causes
are an image URI typo, an ECS execution role that cannot read the secret, or a
task that cannot reach RDS.

## Readiness returns 503

```bash
aws rds describe-db-instances --db-instance-identifier "$(terraform -chdir=infra/environments/staging output -raw rds_endpoint | cut -d: -f1)" \
  --query 'DBInstances[0].DBInstanceStatus'
```

- Confirm the RDS instance is `available`.
- Confirm the ECS task's security group is allowed to reach 5432 on the RDS
  security group.
- Confirm the secret contains the current host/port and that the task has been
  restarted after a database restore.
- Use ECS Exec in staging if enabled:

```bash
aws ecs execute-command \
  --cluster "$CLUSTER" \
  --task <task-id> \
  --container app \
  --interactive \
  --command "/bin/sh"
```

## Rotate the database password

1. Update the password in RDS and in the Secrets Manager secret JSON. A rotation
   Lambda is the recommended production path; this is the manual procedure.
2. Register a new task definition revision (or force a new deployment) so ECS
   re-reads the secret.
3. Verify `/health/ready` and run the smoke test.

Do not put passwords in shell history or Terraform variables. Use the AWS CLI's
`--secret-string` with a file or a secret manager.

## Restore RDS

### Point-in-time restore

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier 8byte-production-pg \
  --target-db-instance-identifier 8byte-production-pg-restore \
  --restore-time 2026-01-01T00:00:00Z \
  --db-instance-class db.t4g.small \
  --db-subnet-group-name 8byte-production-db \
  --vpc-security-group-ids <rds-security-group-id>
```

Update the Secrets Manager `host` to the restored endpoint, redeploy the app, and
run the smoke test. Keep the old instance until the restore is validated.

### Snapshot restore

```bash
aws rds describe-db-snapshots --db-instance-identifier 8byte-production-pg
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier 8byte-production-pg-restore \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t4g.small \
  --db-subnet-group-name 8byte-production-db \
  --vpc-security-group-ids <rds-security-group-id>
```

## Terraform state lock

If a plan is interrupted and the lock remains:

```bash
terraform force-unlock <LOCK_ID>
```

Only do this after confirming no other apply is running. The DynamoDB table
`8byte-tf-lock` shows the current lock item.

## Alarm triage

| Alarm | First checks |
|---|---|
| `alb-target-5xx` | Application logs, recent deploy, DB readiness, task count |
| `alb-elb-5xx` | ALB target health, listener rules, security group, certificate |
| `alb-latency-p95` | RDS slow queries, CPU/memory saturation, task count |
| `alb-unhealthy-hosts` | `/health/ready`, ECS events, task logs, security groups |
| `ecs-cpu-high` / `ecs-memory-high` | Autoscaling events, traffic spike, memory leak |
| `rds-cpu-high` | Slow query log, missing index, connection storm |
| `rds-free-storage` | Table bloat, WAL, autoscaling limits |
| `rds-connections` | Connection leak, pool size, RDS Proxy consideration |
| `app-errors` | Error logs by request ID, recent deploy, dependency status |
| `app-latency-p99` | Slow paths, DB latency, external dependencies |

## Log queries

```sql
SOURCE '/aws/ecs/8byte-production/app'
| fields @timestamp, level, message, request_id, Path, StatusCode, Latency
| filter ErrorCount = 1
| sort @timestamp desc
| limit 50
```

```sql
SOURCE '/aws/ecs/8byte-production/app'
| fields Path, Latency
| filter ispresent(Path)
| stats avg(Latency) as avg_ms, pct(Latency, 99) as p99_ms, count() as requests by Path
| sort p99_ms desc
```

## Cost review

- Delete idle staging stacks; the configuration is disposable.
- Check NAT gateway data processing, CloudWatch log ingestion, and RDS storage.
- Look at ECR lifecycle results and CloudWatch retention.
- Use Cost Explorer tags `Project=8byte` and `Environment=<env>`.

## Emergency shutdown

For a compromised staging environment, set the ECS service desired count to zero
and remove the ALB listener (or restrict the security group). For production,
follow the incident process, preserve logs, and rotate credentials before
restoring service.
