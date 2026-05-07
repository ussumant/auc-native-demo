# auc-native

Native macOS shell for AUC: a local Mac agent you can launch with
**Option+B**, give a task, and watch it execute with visible progress and proof.

This repo is the clean Swift port target. The app is SwiftUI/AppKit first, while
the first executor is the existing AUC Node daemon running headless behind a
JSON-RPC Unix socket.

## Demo Video

Watch the current demo here:
[AUC Native demo on YouTube](https://www.youtube.com/watch?v=MYuemgxvNhg)

[![AUC Native demo video](https://img.youtube.com/vi/MYuemgxvNhg/maxresdefault.jpg)](https://www.youtube.com/watch?v=MYuemgxvNhg)

## Install The Demo

1. Download the latest DMG from the GitHub release:
   [AUC Native 0.1.0 Demo](https://github.com/ussumant/auc-native-demo/releases/tag/v0.1.0-demo)
2. Open the DMG and drag **AUC Native.app** into **Applications**.
3. Launch **AUC Native**.
   - This demo build is dev-signed, not notarized. If macOS blocks the first
     launch, right-click **AUC Native.app**, choose **Open**, then confirm.
4. Open **Settings** and add your **OpenAI API key**.
   - Tasks will not run until the OpenAI key is saved.
5. Press **Option+B** to open the Mac launcher.
6. Type what you want AUC to do and press **Enter**.
   - To force a fresh task from the launcher, start with `/new-task`.

The launcher opened with **Option+B** is the primary interface for the demo. The
main window is useful for history and details, but the launcher is the intended
way to start and continue work.

Verified demo DMG checksum:

```bash
shasum -a 256 ~/Downloads/AUCNative-0.1.0-demo.dmg
```

Expected:

```text
9ee793c1fa5074ea3d91bfaca303caf7cec95b4de94768e1b20ba2b0884c3401
```

## Example Workflows

These are good demo prompts to paste into the **Option+B** launcher.

Use `/new-task` at the start of a prompt when you want to reset context and
start a separate task instead of continuing the active run.

### 1. Smoke Test

```text
Say DMG OK and nothing else.
```

Expected result: the task completes and the output says `DMG OK`.

Fresh-task version:

```text
/new-task Say DMG OK and nothing else.
```

### 2. Find And Summarize A PDF

```text
Find the newest PDF in my Downloads folder and summarize it in 5 bullets.
```

What this shows: local file discovery, task progress, final output, and the full
run in the dashboard.

### 3. Create A File In Downloads

```text
Create a short markdown note in Downloads called auc-demo-note.md with three bullets about why local Mac agents are useful.
```

What this shows: filesystem actions, permission handling when needed, and a
result you can reveal in Finder.

### 4. Send A Birthday iMessage

```text
Send a short birthday iMessage to +1XXXXXXXXXX saying: Happy Birthday to you! Wishing you a fantastic year ahead.
```

What this shows: native macOS app actions through Messages. macOS may ask for
Automation permission the first time AUC controls Messages.

### 5. Follow Up On The Same Run

After a task completes, type a follow-up in the launcher:

```text
Make that warmer and shorter.
```

What this shows: continuing context from the current task instead of starting
from scratch.

### 6. Open A Local Folder

```text
Open my Downloads folder and tell me the three most recent files.
```

What this shows: a quick Mac automation flow that is easy to verify visually.

## Demo Tips

- Use **Option+B** to open the launcher.
- Type `/new-task` in the launcher when you want to reset context.
- Use **New task** from the dashboard for the same reset from the main window.
- Use the dashboard to show history, task progress, output, and full run details.
- Keep the OpenAI key saved in Settings before demoing.
- If a Mac action is blocked, allow AUC Native in **System Settings → Privacy &
  Security → Automation**.

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
