#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <task-definition.json> <image-uri> <output.json> [app-version]" >&2
  exit 2
fi

task_def_file="$1"
image="$2"
output_file="$3"
app_version="${4:-}"

jq --arg image "$image" --arg version "$app_version" '
  del(
    .taskDefinitionArn,
    .revision,
    .status,
    .requiresAttributes,
    .compatibilities,
    .registeredAt,
    .registeredBy,
    .deregisteredAt
  )
  | .containerDefinitions[0].image = $image
  | .containerDefinitions[0] |= del(.command)
  | if $version == "" then .
    else
      .containerDefinitions[0].environment =
        ((.containerDefinitions[0].environment // [])
          | map(if .name == "APP_VERSION" then .value = $version else . end))
    end
' "$task_def_file" > "$output_file"
