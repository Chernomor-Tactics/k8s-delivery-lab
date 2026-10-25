#!/usr/bin/env bash
# Local, credential-free minikube deployment. Does not alter task-lab used by CD.
set -euo pipefail
cd "$(dirname "$0")/.."
profile=${MINIKUBE_PROFILE:-minikube}
for tool in docker minikube kubectl python3; do
  command -v "$tool" >/dev/null || { echo "Missing command: $tool"; exit 1; }
done
minikube status -p "$profile" >/dev/null || {
  echo "Start your cluster first: minikube start -p $profile"
  exit 1
}
# Content-based tag avoids reusing a cached image after source changes.
fingerprint=$(python3 - <<'PYCODE'
import hashlib
from pathlib import Path
paths = [Path('Dockerfile'), Path('requirements.txt'), Path('.dockerignore')]
paths += sorted(p for p in Path('app').rglob('*')
                if p.is_file() and '__pycache__' not in p.parts
                and p.suffix not in ('.pyc', '.pyo'))
h = hashlib.sha256()
for p in paths:
    h.update(str(p).encode() + b'\0' + p.read_bytes() + b'\0')
print(h.hexdigest()[:16])
PYCODE
)
image="task-api:local-${fingerprint}"
docker build -t "$image" .
minikube image load -p "$profile" "$image"
# Namespace first: later multi-object apply must not depend on resource order.
kubectl --context="$profile" create namespace task-lab-local \
  --dry-run=client -o yaml | kubectl --context="$profile" apply -f -
kubectl kustomize k8s-local |
  sed "s|image: task-api:local$|image: ${image}|" |
  kubectl --context="$profile" apply -f -
kubectl --context="$profile" -n task-lab-local rollout status \
  deployment/task-api --timeout=180s
printf '\nLocal deployment ready. In another terminal run:\n'
echo "kubectl --context=$profile -n task-lab-local port-forward service/task-api 8002:80"
echo "Then: bash scripts/smoke-test.sh http://127.0.0.1:8002 local"
