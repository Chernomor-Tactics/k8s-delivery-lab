#!/usr/bin/env bash
set -euo pipefail
base_url=${1:-http://127.0.0.1:8001}
expected_version=${2:-}
python3 - "$base_url" "$expected_version" <<'PYCODE'
import json
import sys
import time
import urllib.error
import urllib.request
base = sys.argv[1].rstrip('/')
expected = sys.argv[2]
for attempt in range(30):
    try:
        with urllib.request.urlopen(base + '/health', timeout=3) as response:
            assert response.status == 200
            assert json.load(response)['status'] == 'ok'
        break
    except (OSError, ValueError, AssertionError, KeyError):
        if attempt == 29:
            raise SystemExit('FAIL: health check did not pass')
        time.sleep(1)
with urllib.request.urlopen(base + '/version', timeout=3) as response:
    actual = json.load(response)['version']
assert isinstance(actual, str) and actual, 'Missing version'
if expected:
    assert actual == expected, f'Expected {expected}, got {actual}'
print(f'PASS: health=ok, version={actual}')
PYCODE
