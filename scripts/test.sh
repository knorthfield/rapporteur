#!/bin/bash
# Run the unit tests on the simulator.
set -euo pipefail
source "$(dirname "$0")/env.sh"
xcodegen generate --quiet
xcodebuild -project Rapporteur.xcodeproj -scheme Rapporteur -destination "$SIM_DEST" \
  -derivedDataPath build test | grep -E "error:|✘|✔ Test run|\*\* TEST" || true
