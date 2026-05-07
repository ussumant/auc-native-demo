# auc-native

Native macOS shell for AUC.

This repo is the clean Swift port target. The app is SwiftUI/AppKit first, while
the first executor is the existing AUC Node daemon running headless behind a
JSON-RPC Unix socket.

## Run

```bash
./script/build_and_run.sh
```

Useful modes:

```bash
./script/build_and_run.sh --verify
```

The script stages a local `.app`, copies the daemon bundle and Node runtime,
deploys daemon production dependencies, and rebuilds native modules against the
bundled Node runtime.

## Test

```bash
swift test
```

## Demo DMG

```bash
./script/package_dmg.sh
```

This creates `dist/AUCNative-0.1.0-demo.dmg` and a SHA-256 checksum. The demo
DMG is dev-signed unless `AUC_SIGN_IDENTITY` is set to a Developer ID
Application identity. See `DEMO_RELEASE.md` for notarization notes.

## Executor

The app looks for an executor in this order:

1. `AUC_EXECUTOR_REPO`, when set.
2. `../agent-computer/accomplish`, relative to this repo.
3. Bundled resources under `AUCNative.app/Contents/Resources/Executor`.

The UI can run in demo mode when the executor is unavailable. That keeps native
UI iteration fast without pretending task execution is wired.
