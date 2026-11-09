# ADR 0002: CloudWatch EMF instead of a metrics sidecar

## Status

Accepted.

## Context

The application needs request rate, error rate, and latency metrics. Options were
a Prometheus sidecar/server, an ADOT/OpenTelemetry collector, or CloudWatch
Embedded Metric Format (EMF) in the existing JSON logs.

## Decision

Emit EMF metrics to stdout from the request middleware. CloudWatch Logs extracts
them into the `8Byte/App` namespace. Keep the Prometheus `/metrics` endpoint for
local development and future migration.

## Consequences

- No additional container, scrape configuration, or IAM role for a metrics agent.
- Metrics are correlated with the exact request log by timestamp and request ID.
- Dimensions are limited to Service and Environment to avoid high-cardinality cost.
- CloudWatch Logs ingestion is the cost driver; retention and sampling can be tuned.
- If the organization standardizes on Prometheus/Grafana, the `/metrics` endpoint
  and a sidecar/collector can replace this without changing application routes.

## Alternatives considered

- **Prometheus sidecar + CloudWatch agent:** more moving parts and another port.
- **ADOT collector:** strong choice for traces and multi-backend export, but more
  configuration than this assignment needs.
- **Metric filters:** brittle string parsing and poor support for multiple metrics
  per request; EMF is the purpose-built mechanism.
