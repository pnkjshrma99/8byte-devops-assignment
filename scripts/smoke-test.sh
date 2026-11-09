#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <base-url> [attempts]" >&2
  exit 2
fi

base_url="${1%/}"
attempts="${2:-30}"
ready=0

for attempt in $(seq 1 "$attempts"); do
  if curl --max-time 10 -fsS "$base_url/health/ready" >/dev/null 2>&1; then
    ready=1
    break
  fi
  echo "waiting for $base_url (attempt $attempt/$attempts)"
  sleep 5
done

if [ "$ready" -ne 1 ]; then
  echo "application did not become ready" >&2
  exit 1
fi

curl --max-time 10 -fsS "$base_url/" | python3 -c '
import json
import sys

body = json.load(sys.stdin)
assert body["status"] == "ok", body
'

item=$(curl --max-time 10 -fsS -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"smoke-test","description":"created by CI"}' \
  "$base_url/api/items")

item_id=$(printf '%s' "$item" | python3 -c '
import json
import sys

print(json.load(sys.stdin)["id"])
')

curl --max-time 10 -fsS "$base_url/api/items/$item_id" >/dev/null
curl --max-time 10 -fsS -X DELETE "$base_url/api/items/$item_id" >/dev/null

echo "smoke test passed against $base_url"
