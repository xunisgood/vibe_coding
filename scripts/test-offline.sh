#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d /tmp/personallife-offline-check.XXXXXX)
BIN="$PWD/dist/我的日常.app/Contents/MacOS/PersonalLife"
for phase in seed read restore; do
  /usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' "$BIN" --data-check "$phase" "$CHECK_DIR/$phase.json"
  python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); assert r["success"],r' "$CHECK_DIR/$phase.json"
done
printf 'Offline evidence: %s\n' "$CHECK_DIR"
