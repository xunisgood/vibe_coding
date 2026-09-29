#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 scripts/generate-xcode-project.py
RESULT_PATH="$PWD/.build/UIResults-$(date +%Y%m%d-%H%M%S).xcresult"
xcrun xcodebuild test -project PersonalLife.xcodeproj -scheme PersonalLife -destination 'platform=macOS' -derivedDataPath .build/XcodeUI -resultBundlePath "$RESULT_PATH" -parallel-testing-enabled NO "$@"
printf 'UI results: %s\n' "$RESULT_PATH"
