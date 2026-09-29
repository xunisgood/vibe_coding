#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d /tmp/personallife-data-check.XXXXXX)
APP="$PWD/dist/我的日常.app"
for phase in seed read restore; do
  open -W -n "$APP" --args --data-check "$phase" "$CHECK_DIR/$phase.json"
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); assert r["success"],r' "$CHECK_DIR/$phase.json"
done
printf 'Evidence: %s\n' "$CHECK_DIR"
