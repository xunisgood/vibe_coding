#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d /tmp/personallife-notification-check.XXXXXX)
APP="$PWD/dist/我的日常.app"
open -W -n "$APP" --args --native-check schedule "$CHECK_DIR/schedule.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); assert r["success"],r' "$CHECK_DIR/schedule.json"
sleep 12
open -W -n "$APP" --args --native-check inspect "$CHECK_DIR/inspect.json"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r); assert r["success"],r' "$CHECK_DIR/inspect.json"
printf 'Evidence: %s\n' "$CHECK_DIR"
