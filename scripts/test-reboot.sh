#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/我的日常.app"
ROOT="$PWD/data/reboot-check"
case "${1:-}" in
  prepare)
    if [[ -e "$ROOT/boot-before.txt" ]]; then
      printf 'A reboot check is already prepared; run verify after reboot.\n' >&2
      exit 1
    fi
    mkdir -p "$ROOT"
    open -W -n "$APP" --args --data-check seed "$ROOT/seed.json"
    python3 - "$ROOT/seed.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
assert result['success'], result
print(result)
PY
    /usr/sbin/sysctl -n kern.boottime > "$ROOT/boot-before.txt"
    printf 'Prepared isolated records. Restart the Mac when convenient, then run: bash scripts/test-reboot.sh verify\n'
    ;;
  verify)
    [[ -f "$ROOT/boot-before.txt" ]]
    /usr/sbin/sysctl -n kern.boottime > "$ROOT/boot-after.txt"
    if cmp -s "$ROOT/boot-before.txt" "$ROOT/boot-after.txt"; then
      printf 'Mac has not rebooted since preparation; verification fails.\n' >&2
      exit 1
    fi
    for phase in read restore; do
      open -W -n "$APP" --args --data-check "$phase" "$ROOT/$phase.json"
      python3 - "$ROOT/$phase.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
assert result['success'], result
print(result)
PY
    done
    printf 'Actual reboot data and restore verification passed. Evidence: %s\n' "$ROOT"
    ;;
  *) printf 'Usage: bash scripts/test-reboot.sh prepare|verify\n' >&2; exit 2 ;;
esac
