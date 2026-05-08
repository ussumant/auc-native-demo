#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AUCNative"
DISPLAY_NAME="AUC Native"
VERSION="${AUC_RELEASE_VERSION:-0.1.0-demo}"
PACKAGE_PROFILE="${AUC_PACKAGE_PROFILE:-full}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_STAGING="$DIST_DIR/$APP_NAME-$VERSION"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

find_developer_id_application() {
  security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' |
    head -1
}

if [[ "$PACKAGE_PROFILE" == "openai-demo" ]]; then
  VERSION="${AUC_RELEASE_VERSION:-0.1.2-openai-demo}"
  DMG_STAGING="$DIST_DIR/$APP_NAME-$VERSION"
  DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
  CHECKSUM_PATH="$DMG_PATH.sha256"
fi

if [[ "$PACKAGE_PROFILE" == "demo-slim" && -z "${AUC_RELEASE_VERSION+x}" ]]; then
  VERSION="0.1.0-demo-slim-rc1"
  DMG_STAGING="$DIST_DIR/$APP_NAME-$VERSION"
  DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
  CHECKSUM_PATH="$DMG_PATH.sha256"
fi

if [[ -n "${AUC_SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$AUC_SIGN_IDENTITY"
elif [[ "$PACKAGE_PROFILE" == "openai-demo" ]]; then
  SIGN_IDENTITY="$(find_developer_id_application)"
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="E67DFD7885D1411C9661415A9B2BD17B58FA4506"
    echo "Developer ID Application identity not found; building dev-signed candidate only." >&2
  fi
else
  SIGN_IDENTITY="E67DFD7885D1411C9661415A9B2BD17B58FA4506"
fi

cd "$ROOT_DIR"

echo "Building release app bundle ($PACKAGE_PROFILE profile)..."
AUC_BUILD_CONFIGURATION=release \
  AUC_SKIP_LAUNCH=1 \
  AUC_SIGN_IDENTITY="$SIGN_IDENTITY" \
  AUC_PACKAGE_PROFILE="$PACKAGE_PROFILE" \
  AUC_RELEASE_VERSION="$VERSION" \
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

Install:
1. Drag "AUC Native.app" to Applications.
2. Open AUC Native.
3. Complete onboarding.
4. Press Option+B to open the launcher and start tasks.

The launcher is the main interface for this demo. Use the full app for history,
settings, and detailed run output.

If this is the openai-demo build, it is OpenAI-only and uses openai/gpt-5.2.
If a seeded demo key was packaged, onboarding will show "Demo key active · $5 budget".

Fallback:
If this candidate does not work, use the previous v0.1.0 demo DMG from the
GitHub release page.

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
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"

if [[ "$PACKAGE_PROFILE" == "openai-demo" ]]; then
  if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    if [[ "${AUC_NOTARIZE:-0}" == "1" ]]; then
      echo "Submitting DMG for notarization..."
      xcrun notarytool submit "$DMG_PATH" --keychain-profile "${AUC_NOTARY_PROFILE:-auc-notary}" --wait
      echo "Stapling notarization ticket..."
      xcrun stapler staple "$DMG_PATH"
      echo "Assessing DMG with Gatekeeper..."
      spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
    else
      echo "Developer ID Application found. Set AUC_NOTARIZE=1 to submit and staple this DMG."
    fi
  else
    echo "Not notarized: Developer ID Application identity is not installed on this Mac." >&2
  fi
fi

echo "Writing checksum..."
shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

echo "Done:"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
