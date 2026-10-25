#!/usr/bin/env bash
set -euo pipefail

release_sha=${1:?Specify the release commit SHA}
collection=${2:?Specify the Postman collection path}

[[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo "Expected a full lowercase commit SHA"
  exit 1
}

image="ghcr.io/chernomor-tactics/k8s-delivery-lab:sha-${release_sha}"

# Меняем образ и APP_VERSION одним обновлением Deployment.
patch=$(python3 - "$image" "$release_sha" <<'PY'
import json
import sys

print(json.dumps({
    "spec": {
        "template": {
            "spec": {
                "containers": [{
                    "name": "api",
                    "image": sys.argv[1],
                    "env": [{
                        "name": "APP_VERSION",
                        "value": sys.argv[2]
                    }]
                }]
            }
        }
    }
}))
PY
)

kubectl --context=minikube -n task-lab patch deployment task-api \
  --type=strategic -p "$patch"

kubectl --context=minikube -n task-lab rollout status \
  deployment/task-api --timeout=180s

# Отдельный порт для CD, чтобы не занимать твой 8002.
forward_log=$(mktemp)
kubectl --context=minikube -n task-lab port-forward \
  service/task-api 18002:80 >"$forward_log" 2>&1 &
forward_pid=$!

cleanup() {
  kill "$forward_pid" 2>/dev/null || true
  wait "$forward_pid" 2>/dev/null || true
  rm -f "$forward_log"
}
trap cleanup EXIT

ready=false
for attempt in {1..30}; do
  if ! kill -0 "$forward_pid" 2>/dev/null; then
    cat "$forward_log"
    exit 1
  fi

  if curl --fail --silent --max-time 2 \
    http://127.0.0.1:18002/health >/dev/null; then
    ready=true
    break
  fi
  sleep 1
done

if [[ "$ready" != true ]]; then
  cat "$forward_log"
  echo "Application is unavailable"
  exit 1
fi

actual_version=$(curl --fail --silent --show-error --max-time 5 \
  http://127.0.0.1:18002/version |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')

[[ "$actual_version" == "$release_sha" ]] || {
  echo "Version mismatch: expected $release_sha, got $actual_version"
  exit 1
}

npx --yes newman@6.2.1 run "$collection" \
  --env-var base_url=http://127.0.0.1:18002 \
  --timeout-request 5000 \
  --bail
