#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/test.sh
bash scripts/build-app.sh
bash scripts/test-data-processes.sh
bash scripts/test-offline.sh
bash scripts/test-notifications.sh
bash scripts/test-ui.sh
python3 scripts/check-repository.py
