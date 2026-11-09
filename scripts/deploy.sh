#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <ecs-cluster> <ecs-service> <image-uri> [task-family] [app-version]" >&2
  exit 2
fi

cluster="$1"
service="$2"
image="$3"
family="${4:-}"
app_version="${5:-}"

if [ -z "$family" ]; then
  family=$(aws ecs describe-services \
    --cluster "$cluster" \
    --services "$service" \
    --query 'services[0].taskDefinition' \
    --output text | awk -F/ '{print $2}')
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

aws ecs describe-task-definition \
  --task-definition "$family" \
  --query 'taskDefinition' > "$tmp_dir/taskdef.json"

"$(dirname "$0")/render-task-def.sh" \
  "$tmp_dir/taskdef.json" "$image" "$tmp_dir/new-taskdef.json" "$app_version"

new_task_definition=$(aws ecs register-task-definition \
  --cli-input-json "file://$tmp_dir/new-taskdef.json" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

aws ecs update-service \
  --cluster "$cluster" \
  --service "$service" \
  --task-definition "$new_task_definition" \
  --force-new-deployment \
  --query 'service.{serviceName:serviceName,taskDefinition:taskDefinition,desiredCount:desiredCount}' \
  --output table

aws ecs wait services-stable --cluster "$cluster" --services "$service"
echo "$new_task_definition"
