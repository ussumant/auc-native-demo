#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AUCNative"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_CONFIGURATION="${AUC_BUILD_CONFIGURATION:-debug}"
PRODUCT_BIN="$ROOT_DIR/.build/$BUILD_CONFIGURATION/AUCNative"
EXECUTOR_REPO="${AUC_EXECUTOR_REPO:-$ROOT_DIR/../agent-computer/accomplish}"
SIGN_IDENTITY="${AUC_SIGN_IDENTITY:--}"
ICON_SOURCE="${AUC_ICON_SOURCE:-$ROOT_DIR/Assets/AppIcon.icns}"
PACKAGE_PROFILE="${AUC_PACKAGE_PROFILE:-full}"

is_demo_slim() {
  [[ "$PACKAGE_PROFILE" == "demo-slim" || "$PACKAGE_PROFILE" == "openai-demo" ]]
}

is_openai_demo() {
  [[ "$PACKAGE_PROFILE" == "openai-demo" ]]
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

echo "Building $APP_NAME ($PACKAGE_PROFILE profile)..."
cd "$ROOT_DIR"
swift build -c "$BUILD_CONFIGURATION"

echo "Staging app bundle at $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/Executor"
cp "$PRODUCT_BIN" "$MACOS_DIR/AUCNative"
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi
if is_openai_demo && [[ -f "$ROOT_DIR/Assets/BoringNotch-boring.m4a" ]]; then
  cp "$ROOT_DIR/Assets/BoringNotch-boring.m4a" "$RESOURCES_DIR/BoringNotch-boring.m4a"
fi

if [[ -d "$EXECUTOR_REPO/apps/daemon/dist" ]]; then
  mkdir -p "$RESOURCES_DIR/Executor/daemon"
  rsync -a --delete "$EXECUTOR_REPO/apps/daemon/dist/" "$RESOURCES_DIR/Executor/daemon/"

  if command -v pnpm >/dev/null; then
    DEPLOY_DIR="$(mktemp -d)"
    echo "Staging daemon production dependencies..."
    (
      cd "$EXECUTOR_REPO"
      pnpm --filter @auc/daemon deploy --prod --legacy "$DEPLOY_DIR" >/dev/null
    )
    if [[ -d "$DEPLOY_DIR/node_modules" ]]; then
      rsync -a --delete "$DEPLOY_DIR/node_modules/" "$RESOURCES_DIR/Executor/daemon/node_modules/"
      if ! is_demo_slim; then
        mkdir -p "$RESOURCES_DIR/app.asar.unpacked/node_modules"
        rsync -a --delete "$DEPLOY_DIR/node_modules/" "$RESOURCES_DIR/app.asar.unpacked/node_modules/"
      fi
    fi
    rm -rf "$DEPLOY_DIR"

  else
    echo "pnpm not found; daemon native dependencies were not bundled." >&2
  fi
fi

if [[ -d "$EXECUTOR_REPO/apps/desktop/resources/nodejs" ]]; then
  mkdir -p "$RESOURCES_DIR/nodejs"
  rsync -a --delete "$EXECUTOR_REPO/apps/desktop/resources/nodejs/" "$RESOURCES_DIR/nodejs/"
  if ! is_demo_slim; then
    mkdir -p "$RESOURCES_DIR/Executor/nodejs"
    rsync -a --delete "$EXECUTOR_REPO/apps/desktop/resources/nodejs/" "$RESOURCES_DIR/Executor/nodejs/"
  fi
fi

if [[ -d "$EXECUTOR_REPO/node_modules/.pnpm/node_modules/opencode-ai" ]]; then
  mkdir -p "$RESOURCES_DIR/app.asar.unpacked/node_modules"
  rsync -aL --delete "$EXECUTOR_REPO/node_modules/.pnpm/node_modules/opencode-ai" "$RESOURCES_DIR/app.asar.unpacked/node_modules/"
  if is_demo_slim; then
    rm -f "$RESOURCES_DIR/app.asar.unpacked/node_modules/opencode-ai/bin/.opencode"
  fi
fi

if [[ -d "$EXECUTOR_REPO/node_modules/.pnpm/node_modules/opencode-darwin-arm64" ]]; then
  mkdir -p "$RESOURCES_DIR/app.asar.unpacked/node_modules"
  rsync -aL --delete "$EXECUTOR_REPO/node_modules/.pnpm/node_modules/opencode-darwin-arm64" "$RESOURCES_DIR/app.asar.unpacked/node_modules/"
fi

if [[ -d "$EXECUTOR_REPO/packages/agent-core/mcp-tools" ]]; then
  mkdir -p "$RESOURCES_DIR/mcp-tools"
  if is_demo_slim; then
    rm -rf "$RESOURCES_DIR/mcp-tools"
    mkdir -p "$RESOURCES_DIR/mcp-tools"
    for item in package.json package-lock.json request-connector-auth request-google-file-picker start-task complete-task mac-actions dev-browser dev-browser-mcp gmail-mcp calendar-mcp gws-mcp whatsapp safe-file-deletion; do
      if [[ -e "$EXECUTOR_REPO/packages/agent-core/mcp-tools/$item" ]]; then
        rsync -a --delete "$EXECUTOR_REPO/packages/agent-core/mcp-tools/$item" "$RESOURCES_DIR/mcp-tools/"
      fi
    done
  else
    rsync -a --delete "$EXECUTOR_REPO/packages/agent-core/mcp-tools/" "$RESOURCES_DIR/mcp-tools/"
  fi
fi

if [[ -d "$EXECUTOR_REPO/bundled-skills" ]]; then
  mkdir -p "$RESOURCES_DIR/bundled-skills"
  rsync -a --delete "$EXECUTOR_REPO/bundled-skills/" "$RESOURCES_DIR/bundled-skills/"
fi

if [[ -d "$EXECUTOR_REPO/apps/web/public/fonts" ]]; then
  mkdir -p "$RESOURCES_DIR/fonts"
  rsync -a --delete "$EXECUTOR_REPO/apps/web/public/fonts/" "$RESOURCES_DIR/fonts/"
fi

NODE_BIN_DIR="$RESOURCES_DIR/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin"
if [[ ! -x "$NODE_BIN_DIR/node" ]]; then
  NODE_BIN_DIR="$RESOURCES_DIR/Executor/nodejs/darwin-arm64/node-v24.15.0-darwin-arm64/bin"
fi
if [[ -x "$NODE_BIN_DIR/node" && -x "$NODE_BIN_DIR/npm" && -d "$RESOURCES_DIR/Executor/daemon/node_modules" ]]; then
  echo "Rebuilding daemon native modules for bundled Node..."
  (
    cd "$RESOURCES_DIR/Executor/daemon"
    PATH="$NODE_BIN_DIR:$PATH" npm rebuild better-sqlite3 --build-from-source=true >/dev/null
  )
fi

if is_demo_slim; then
  rm -f "$RESOURCES_DIR/Executor/daemon/node_modules/.pnpm/node_modules/@auc/daemon" 2>/dev/null || true
  find "$RESOURCES_DIR/Executor/daemon" -name '*.map' -type f -delete 2>/dev/null || true
fi

if is_openai_demo; then
  DEMO_KEY_JSON=""
  if [[ -n "${AUC_DEMO_OPENAI_API_KEY:-}" ]]; then
    DEMO_KEY_JSON=",\n  \"seededOpenAIAPIKey\": \"$(json_escape "$AUC_DEMO_OPENAI_API_KEY")\""
  fi
  printf '{\n  "profile": "openai-demo",\n  "releaseVersion": "0.1.1-openai-demo"%b\n}\n' "$DEMO_KEY_JSON" > "$RESOURCES_DIR/DemoReleaseConfig.json"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>AUC Native</string>
  <key>CFBundleExecutable</key>
  <string>AUCNative</string>
  <key>CFBundleIdentifier</key>
  <string>ai.auc.native</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>AUC Native</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026 AUC</string>
</dict>
</plist>
PLIST

echo "Signing app bundle..."
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

if [[ "${AUC_SKIP_LAUNCH:-0}" == "1" ]]; then
  exit 0
fi

echo "Launching $APP_NAME..."
pkill -f "$MACOS_DIR/AUCNative" 2>/dev/null || true
pkill -f "AUCNative/daemon.sock" 2>/dev/null || true
rm -f "$HOME/Library/Application Support/AUCNative/daemon.sock" "$HOME/Library/Application Support/AUCNative/daemon.pid"
open "$APP_DIR"

if [[ "${1:-}" == "--verify" ]]; then
  for _ in {1..30}; do
    if pgrep -f "$MACOS_DIR/AUCNative" >/dev/null; then
      echo "$APP_NAME is running."
      exit 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $APP_NAME to launch." >&2
  exit 1
fi
