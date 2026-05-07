#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/AUCNative.app}"
DMG_PATH="${2:-$ROOT_DIR/dist/AUCNative-0.1.0-demo-slim-rc1.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

echo "AUC package size report"
echo "======================="
echo

echo "Artifacts"
du -sh "$APP_PATH"
if [[ -f "$DMG_PATH" ]]; then
  du -sh "$DMG_PATH"
fi
echo

echo "App Contents"
du -sh "$APP_PATH"/Contents/* 2>/dev/null | sort -hr
echo

echo "Resources"
du -sh "$APP_PATH"/Contents/Resources/* 2>/dev/null | sort -hr
echo

echo "Focused Runtime Buckets"
for path in \
  "$APP_PATH/Contents/Resources/Executor/daemon/node_modules" \
  "$APP_PATH/Contents/Resources/app.asar.unpacked/node_modules" \
  "$APP_PATH/Contents/Resources/Executor/nodejs" \
  "$APP_PATH/Contents/Resources/nodejs" \
  "$APP_PATH/Contents/Resources/mcp-tools" \
  "$APP_PATH/Contents/Resources/bundled-skills" \
  "$APP_PATH/Contents/Resources/fonts" \
  "$APP_PATH/Contents/_CodeSignature"; do
  [[ -e "$path" ]] && du -sh "$path"
done | sort -hr
echo

echo "Top Files"
find "$APP_PATH" -type f -print0 2>/dev/null | xargs -0 du -h | sort -hr | head -40
echo

echo "Resource File Count"
find "$APP_PATH/Contents/Resources" -type f 2>/dev/null | wc -l | tr -d ' '
echo
