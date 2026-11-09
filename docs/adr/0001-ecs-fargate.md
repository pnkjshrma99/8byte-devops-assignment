# ADR 0001: ECS Fargate for application hosting

## Status

Accepted.

## Context

The assignment requires application hosting on AWS with a load balancer, rolling
deployments, and operational metrics. The service is a small stateless HTTP API.
The alternatives were EC2 Auto Scaling, ECS on EC2, EKS, or Fargate.

## Decision

Use ECS Fargate with an Application Load Balancer and target-tracking autoscaling.

## Consequences

- No node groups to patch or capacity-plan; the platform team owns less undifferentiated work.
- No fixed EKS control-plane cost, which matters for a small service and a demo account.
- Slightly higher per-task compute cost than optimized EC2 capacity.
- Fargate Spot is available for staging; production uses on-demand tasks.
- Container Insights provides task/service metrics without operating a metrics server.

## Alternatives considered

- **EKS:** better if the organization already has a Kubernetes platform and needs
  the ecosystem. Overkill for one service.
- **EC2 Auto Scaling:** cheapest at steady high utilization, but requires AMI
  pipelines, patching, and a CloudWatch agent for memory/disk.
- **ECS on EC2:** middle ground, but still requires capacity and patching ownership.
