#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TraceBar.xcodeproj"
SCHEME="TraceBar"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/TraceBar.app"
INSTALL_PATH="/Applications/TraceBar.app"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

pkill -x TraceBar 2>/dev/null || true
sleep 1
ditto "$APP" "$INSTALL_PATH"
open "$INSTALL_PATH"
