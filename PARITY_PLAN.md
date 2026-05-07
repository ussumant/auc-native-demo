# AUC Native Parity Plan

Goal: bring the native Swift Mac app to parity with the latest modified Electron AUC app while keeping the proven Node daemon as the executor until Swift runtime slices have tested parity.

## Current Baseline

- Native app launches from `dist/AUCNative.app`.
- OpenAI key save works through the daemon.
- Task launch now reaches the bundled daemon and OpenCode runtime in local dev.
- Launcher is present through `Option-B`, the bottom launcher pill, and the sidebar launcher button.
- UI tokens have been moved toward the AUC dark/violet system.

Known gaps:
- The native UI still represents only the core shell, not the full latest Electron UX.
- Task progress is partly polling-based; daemon notifications are not yet fully consumed as a live event stream.
- Permission approval, artifact proof, browser/tool frames, and richer task messages are not fully rendered.
- Attachments/folder flows exist but need Electron-level validation and display states.
- Settings only covers OpenAI/provider basics, not the full provider/diagnostics surface.

## Milestone 0: Runtime Contract Lock

Objective: make task start/cancel/follow-up reliable before polishing more UI.

Tasks:
- Confirm daemon launch uses the same runtime layout as Electron in both dev and packaged modes.
- Keep local dev `APP_ROOT` pointed at pnpm's virtual root when needed.
- Keep packaged resources staged at:
  - `Contents/Resources/nodejs`
  - `Contents/Resources/app.asar.unpacked/node_modules/opencode-ai`
  - `Contents/Resources/mcp-tools`
  - `Contents/Resources/Executor/daemon`
- Add a launch regression test for OpenCode runtime discovery.
- Add a smoke script that starts a harmless task, receives progress, then cancels it.

Exit criteria:
- `task.start` never returns "OpenCode runtime is not available" in the staged app.
- `task.cancel` works on the smoke task.
- Xcode build, `swift test`, and `script/build_and_run.sh --verify` pass.

## Milestone 1: Live Task Event Bridge

Objective: make the native app feel alive like Electron during execution.

Tasks:
- Replace polling-only updates with a notification-aware daemon reader.
- Decode:
  - `task.progress`
  - `task.message`
  - `task.statusChange`
  - `task.summary`
  - `task.complete`
  - `task.error`
  - `todo.update`
  - `permission.request`
  - `browser.frame`
- Store an event timeline in native state.
- Preserve request/response matching while dispatching notifications.
- Add tests for interleaved notifications before, during, and after RPC responses.

Exit criteria:
- Starting a task updates active status without manual refresh.
- Current action, messages, todos, and terminal state update live.
- Interleaved daemon notifications do not break RPC calls.

## Milestone 2: Launcher Parity

Objective: port the Electron launcher behavior, not just its appearance.

Tasks:
- Match launcher entry points:
  - `Option-B`
  - bottom floating launcher
  - sidebar launcher
  - active-task follow-up button
- Support modes:
  - search history
  - new task
  - follow-up on active task
  - attach to selected historical task
  - collapsed and expanded states
- Add keyboard navigation:
  - up/down selection
  - return to select/start
  - escape to close
- Keep typed launcher prompt on failure.
- Show inline daemon/provider errors.
- Add visual active-task header and permission mini-card.

Exit criteria:
- The launcher can start a new task, resume a task, search history, and submit a follow-up.
- Failed task start leaves the prompt visible with an actionable error.
- Screenshot matches Electron launcher proportions and token use.

## Milestone 3: Command Composer Parity

Objective: make the home command flow match the modified Electron app.

Tasks:
- Match the latest Electron composer spacing, typography, borders, glow, and dark/violet tokens.
- Port:
  - prompt field
  - model indicator
  - mic slot
  - plus menu
  - file attachment affordance
  - folder/working-directory chip
  - examples
  - favorites/recent prompts
- Add disabled states:
  - no provider
  - empty prompt
  - task already submitting
- Add attachment chips with remove buttons and file-specific error states.
- Route plus menu to the expected actions instead of duplicating file picker behavior.

Exit criteria:
- Main composer visually reads as the same product as the Electron app.
- Prompt-only, file attachment, folder working directory, and provider-missing states are all visible and tested.

## Milestone 4: Execution Surface Parity

Objective: port the active task/proof experience from Electron.

Tasks:
- Render task timeline messages:
  - user prompt
  - assistant updates
  - tool calls
  - tool running/completed/error state
- Render progress stages:
  - starting
  - browser
  - environment
  - loading
  - thinking
  - tool-use
  - waiting
  - complete
- Add stop/interrupt actions.
- Render todos.
- Render artifacts with reveal/open actions.
- Render browser/tool frame events if the daemon emits them.
- Show proof card only when task data supports it; otherwise show verifier missing/incomplete.

Exit criteria:
- A real task shows progress, tool activity, completion, and proof/artifact state without pretending success.
- Cancel/interrupt update the UI immediately and persist through daemon refresh.

## Milestone 5: Permission Flow Parity

Objective: native approval flow must match Electron's safety behavior.

Tasks:
- Decode `permission.request`.
- Show native approval sheet/card with task context.
- Implement allow/deny through `permission.respond`.
- Auto-deny or clearly fail when no visible UI can answer.
- Add tests for permission request while launcher is open, while main window is focused, and while task panel is active.

Exit criteria:
- No permission request can arrive silently.
- User can approve/deny and see the task continue or stop.

## Milestone 6: Settings And Diagnostics Parity

Objective: settings must be useful enough to operate the app.

Tasks:
- Keep OpenAI API key save and selected model working.
- Add provider readiness summary.
- Add base URL editing.
- Add daemon status:
  - connected
  - socket path
  - data dir
  - runtime path
  - OpenCode availability
- Add repair actions:
  - reconnect daemon
  - relaunch daemon
  - copy diagnostics
- Add local folders and permissions section.
- Add visible error states for provider missing and runtime missing.

Exit criteria:
- A user can diagnose why tasks cannot run from Settings without reading logs.
- OpenAI setup, refresh, and model selection survive app relaunch.

## Milestone 7: History And Sidebar Parity

Objective: native history should behave like the Electron task list.

Tasks:
- Load and refresh task history from daemon.
- Show status dots and readable status labels.
- Select task into active panel.
- Search/filter tasks from launcher and sidebar.
- Add delete task.
- Add favorite/star placeholder if present in Electron UI.
- Preserve selected task across refresh.

Exit criteria:
- Completed, failed, cancelled, and running tasks appear correctly after app relaunch.
- Selecting a history row restores the task context and enables follow-up when a session id exists.

## Milestone 8: Visual Token Audit

Objective: make the native app visually match the latest modified Electron app.

Tasks:
- Extract final Electron tokens into a documented Swift `AUCDesign` mapping.
- Audit:
  - colors
  - radius
  - shadows/glow
  - typography
  - panel opacity
  - spacing scale
  - status colors
- Replace remaining arbitrary layout values where practical.
- Capture screenshots:
  - main empty state
  - settings provider ready
  - launcher open
  - active running task
  - task failed state
  - completed proof state
- Compare against Electron screenshots.

Exit criteria:
- The app looks like a native version of the Electron app, not a generic Swift scaffold.
- No obvious label wrapping, clipped text, or mismatched control proportions at 1440x900.

## Milestone 9: Acceptance Test Matrix

Objective: lock parity with repeatable tests.

Required flows:
- Open app -> provider ready -> start task -> see progress -> cancel.
- Open app -> start prompt-only task -> complete -> see proof.
- Attach file -> start task -> see attachment chip and daemon payload.
- Set working folder -> start task -> daemon receives working directory.
- Open launcher -> search history -> select task.
- Active task -> send follow-up.
- Permission request -> approve -> task continues.
- Runtime missing -> settings shows repair diagnostic.
- Provider missing -> composer routes to settings.

Required automation:
- Swift unit tests for state mapping.
- JSON-RPC fake server tests for event interleaving.
- Integration smoke test against the bundled daemon.
- Screenshot captures for key UI states.

## Execution Order

1. Finish Milestone 0 runtime contract and smoke script.
2. Build Milestone 1 event bridge.
3. Bring Launcher and Composer to parity in Milestones 2 and 3.
4. Bring Execution, Permission, and Settings surfaces to parity in Milestones 4, 5, and 6.
5. Complete History and visual audit in Milestones 7 and 8.
6. Lock with the acceptance test matrix in Milestone 9.

## Non-Goals For This Parity Pass

- Rewriting the daemon in Swift.
- Removing Node.
- Rebuilding connectors, scheduler, WhatsApp, and skills management unless required by visible task parity.
- App Store packaging.
