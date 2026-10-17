#!/bin/bash
# Builds the release binary and assembles it into Scrim.app.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Scrim.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS"

cp .build/release/Scrim "$APP/Contents/MacOS/Scrim"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - --identifier com.krkrishnaraj.scrim "$APP"

echo "Built $APP"
echo "Run with: open $APP"
