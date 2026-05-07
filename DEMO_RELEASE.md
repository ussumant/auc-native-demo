# AUC Native Demo Release

This repo can produce a demo DMG with the bundled Node executor and the
ScreenRecorder app icon.

## Build

```bash
swift test
./script/package_dmg.sh
```

Outputs:

- `dist/AUCNative-0.1.0-demo.dmg`
- `dist/AUCNative-0.1.0-demo.dmg.sha256`

## Signing Status

The current demo DMG is signed with the locally available Apple Development
identity:

```text
Apple Development: ussumant@gmail.com (CZN9RWWYB4)
```

The packaging script uses the identity hash by default because two local
certificates have the same display name.

`codesign --verify --deep` is the validation used for the demo bundle. The
stricter `--strict` verifier can report a misleading missing-file error inside
the bundled Node dependency tree; resolve that before Developer ID notarization.

It is not notarized because this machine does not currently have a Developer ID
Application certificate installed. Recipients may need to right-click the app
and choose Open on first launch.

## Notarized Release Follow-up

After installing a Developer ID Application certificate:

```bash
AUC_SIGN_IDENTITY="Developer ID Application: ..." ./script/package_dmg.sh
xcrun notarytool submit dist/AUCNative-0.1.0-demo.dmg --keychain-profile auc-notary --wait
xcrun stapler staple dist/AUCNative-0.1.0-demo.dmg
spctl --assess --type open --context context:primary-signature --verbose=4 dist/AUCNative-0.1.0-demo.dmg
```
