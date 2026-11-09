# ADR 0003: Separate environment roots with one shared module

## Status

Accepted.

## Context

Staging and production need separate state and blast radius. Terraform workspaces
or a single root with `-var-file` switching are common alternatives.

## Decision

Use `infra/environments/staging` and `infra/environments/production`, each with its
own S3 backend key and tfvars, both calling `infra/modules/stack`. The bootstrap
root creates the state bucket, lock table, and OIDC provider.

## Consequences

- A production apply cannot accidentally use staging state.
- Module changes are planned in each environment independently.
- The environment roots are intentionally thin; most logic lives in the module.
- Some variable plumbing is duplicated at the root, which is acceptable for two
  environments and makes each root explicit.
- Adding environments means copying a small root and adding a backend key.

## Alternatives considered

- **Workspaces:** less duplication, but `terraform workspace select` is an easy
  human error and the state key becomes less obvious.
- **Terragrunt:** good at scale, but adds a tool and indirection that is not needed
  for two environments.
- **Single root with var files:** simplest, but one state file for both
  environments is a poor blast-radius boundary.
