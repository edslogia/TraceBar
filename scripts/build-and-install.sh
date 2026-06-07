#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/graphic-monitor.xcodeproj"
SCHEME="graphic-monitor"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/graphic-monitor.app"
INSTALL_PATH="/Applications/graphic-monitor.app"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

pkill -x graphic-monitor 2>/dev/null || true
sleep 1
ditto "$APP" "$INSTALL_PATH"
open "$INSTALL_PATH"
