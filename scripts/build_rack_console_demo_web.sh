#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

DEMO_SCENARIO_SECONDS="${DEMO_SCENARIO_SECONDS:-45}"

flutter build web \
  --release \
  --dart-define=APP_VARIANT=rack_console \
  --dart-define=DEMO_MODE=true \
  --dart-define=DEMO_SCENARIO_ROTATION=true \
  --dart-define=DEMO_SCENARIO_SECONDS="${DEMO_SCENARIO_SECONDS}"

echo
echo "Rack Console demo web build is ready at:"
echo "  ${PROJECT_ROOT}/build/web"
