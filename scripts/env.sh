#!/bin/bash
# Shared settings and steps for the build scripts.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [ ! -f "$ROOT/Local.xcconfig" ]; then
  printf '// Team-specific settings. Not committed. Needed only for a real device.\n// DEVELOPMENT_TEAM = XXXXXXXXXX\n' > "$ROOT/Local.xcconfig"
fi
BUNDLE_ID="com.krisnorthfield.rapporteur"
SIM_NAME="${SIM_NAME:-iPhone 17}"
# OS=latest picks the newest of two simulators that share a name.
SIM_DEST="platform=iOS Simulator,name=$SIM_NAME,OS=latest"
APP_PATH="$ROOT/build/Build/Products/Debug-iphonesimulator/Rapporteur.app"

# build_scheme <scheme> <destination> [xcodebuild args...]: regenerate the project and build.
build_scheme() {
  local scheme="$1" destination="$2"; shift 2
  xcodegen generate --quiet
  xcodebuild -project Rapporteur.xcodeproj -scheme "$scheme" -destination "$destination" \
    -derivedDataPath build "$@" build | grep -E "error:|warning:|BUILD" || true
}

# install_and_launch <simulator> <app path> <bundle id> [app args...]
install_and_launch() {
  local sim="$1" app="$2" bundle="$3"; shift 3
  xcrun simctl boot "$sim" 2>/dev/null || true
  open -a "$DEVELOPER_DIR/../Applications/DeviceHub.app"
  xcrun simctl install "$sim" "$app"
  xcrun simctl launch "$sim" "$bundle" "$@"
}
