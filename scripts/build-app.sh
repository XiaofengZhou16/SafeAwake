#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/SafeAwake.app"

cd "$PROJECT_DIR"
swift build -c release --disable-sandbox

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/.build/release/SafeAwake" "$APP_DIR/Contents/MacOS/SafeAwake"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Ad-hoc signing avoids an unidentified modified-bundle warning for local builds.
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
