#!/usr/bin/env bash
set -euo pipefail

npx --yes newman@6.2.1 run tests/postman/task-api.postman_collection.json \
  --env-var "base_url=${1:-http://127.0.0.1:8001}" \
  --timeout-request 5000 \
  --bail