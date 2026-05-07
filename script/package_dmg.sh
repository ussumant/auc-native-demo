#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AUCNative"
DISPLAY_NAME="AUC Native"
VERSION="${AUC_RELEASE_VERSION:-0.1.0-demo}"
SIGN_IDENTITY="${AUC_SIGN_IDENTITY:-E67DFD7885D1411C9661415A9B2BD17B58FA4506}"
PACKAGE_PROFILE="${AUC_PACKAGE_PROFILE:-full}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_STAGING="$DIST_DIR/$APP_NAME-$VERSION"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

if [[ "$PACKAGE_PROFILE" == "demo-slim" && -z "${AUC_RELEASE_VERSION+x}" ]]; then
  VERSION="0.1.0-demo-slim-rc1"
  DMG_STAGING="$DIST_DIR/$APP_NAME-$VERSION"
  DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
  CHECKSUM_PATH="$DMG_PATH.sha256"
fi

cd "$ROOT_DIR"

echo "Building release app bundle ($PACKAGE_PROFILE profile)..."
AUC_BUILD_CONFIGURATION=release \
  AUC_SKIP_LAUNCH=1 \
  AUC_SIGN_IDENTITY="$SIGN_IDENTITY" \
  AUC_PACKAGE_PROFILE="$PACKAGE_PROFILE" \
  ./script/build_and_run.sh

echo "Verifying app signature..."
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Preparing DMG staging..."
rm -rf "$DMG_STAGING" "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/$DISPLAY_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
cat > "$DMG_STAGING/README-FIRST.txt" <<'README'
AUC Native demo build
=====================

This is a dev-signed demo build, not a notarized public release.

If macOS blocks first launch on another Mac:
1. Move "AUC Native.app" to Applications.
2. Control-click or right-click the app.
3. Choose Open.
4. Confirm Open again if Gatekeeper asks.

For a fully trusted public build, install a Developer ID Application certificate,
rebuild, submit the DMG with notarytool, and staple the notarization ticket.
README

echo "Creating DMG..."
hdiutil create \
  -volname "$DISPLAY_NAME $VERSION" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "Writing checksum..."
shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

echo "Done:"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
