#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building ClaudeMonitor..."
swift build -c release 2>&1

BINARY=".build/release/ClaudeMonitor"
APP_DIR="ClaudeMonitor.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/"
cp Info.plist "$APP_DIR/Contents/"
cp Scripts/statusline-wrapper.sh "$APP_DIR/Contents/Resources/"

echo "Built: $APP_DIR"
echo "Run:   open $APP_DIR"
