#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/我的日常.app"
TARGET="$HOME/Applications/我的日常.app"
if [[ ! -d "$APP" ]]; then
  printf 'Please run bash scripts/build-app.sh first.\n' >&2
  exit 1
fi
if pgrep -x PersonalLife >/dev/null; then
  printf 'Please quit 我的日常 before installing.\n' >&2
  exit 1
fi
codesign --verify --strict "$APP"
mkdir -p "$HOME/Applications"
if [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$HOME/Applications/我的日常.previous-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$APP" "$TARGET"
codesign --verify --strict "$TARGET"
printf 'Installed: %s\n' "$TARGET"
