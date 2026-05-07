import AUCNativeCore
import SwiftUI

struct MacLauncherPanelView: View {
    @Bindable var model: AUCAppModel
    let close: () -> Void
    let resize: (Bool) -> Void

    @State private var userExpandedTerminalTaskID: String?
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        Group {
            if let task = model.activeTask {
                if model.isLauncherCollapsed {
                    minimizedTask(task)
                } else {
                    expandedTask(task)
                }
            } else if model.isLauncherCollapsed, model.isBusy {
                pendingTask
            } else {
                idlePill
            }
        }
        .padding(1)
        .background(Color.clear)
        .onKeyPress(.return) {
            startFromLauncher()
            return .handled
        }
        .onAppear {
            model.isLauncherCollapsed = false
            resize(false)
            isPromptFocused = true
        }
        .onChange(of: model.isLauncherCollapsed) { _, value in
            resize(value)
            if !value {
                isPromptFocused = true
            }
        }
        .onChange(of: model.activeTask?.id) { _, _ in
            userExpandedTerminalTaskID = nil
            resize(model.isLauncherCollapsed)
            if !model.isLauncherCollapsed {
                isPromptFocused = true
            }
        }
        .onChange(of: model.activeTask?.status) { _, status in
            if status?.isTerminal == true, userExpandedTerminalTaskID != model.activeTask?.id {
                model.isLauncherCollapsed = true
                resize(true)
            } else {
                resize(model.isLauncherCollapsed)
                if status?.isTerminal == true {
                    isPromptFocused = true
                }
            }
        }
        .onChange(of: model.permissionRequest?.id) { _, _ in
            resize(model.isLauncherCollapsed)
        }
    }

    private var idlePill: some View {
        HStack(spacing: AUCDesign.Space.md) {
            Image(systemName: "magnifyingglass")
                .font(AUCDesign.FontToken.sans(size: 21, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)

            TextField("What do you want done?", text: $model.launcherQuery)
                .textFieldStyle(.plain)
                .font(AUCDesign.FontToken.sans(size: 18, weight: .regular))
                .focused($isPromptFocused)
                .onSubmit(startFromLauncher)

            Button(action: startFromLauncher) {
                Image(systemName: "plus")
                    .font(AUCDesign.FontToken.sans(size: 22, weight: .medium))
            }
            .buttonStyle(LauncherCircleButtonStyle(kind: .primary))
            .keyboardShortcut(.return, modifiers: [])
            .disabled(model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(LauncherCircleButtonStyle(kind: .plain))
            .help("Close")
        }
        .padding(.leading, AUCDesign.Space.xl)
        .padding(.trailing, AUCDesign.Space.md)
        .frame(height: AUCDesign.Space.launcherIdleHeight)
        .launcherChrome(cornerRadius: 38)
    }

    private func expandedTask(_ task: AUCTaskRecord) -> some View {
        VStack(spacing: 0) {
            taskHeader(task)

            Divider().overlay(AUCDesign.ColorToken.stroke)

            if let request = model.permissionRequest, request.taskID == task.id {
                permissionContent(request)
            } else if task.status == .completed {
                responseContent(task)
            } else if task.status.isTerminal {
                terminalContent(task)
            } else {
                runningContent(task)
            }

            followUpBar
        }
        .launcherChrome(cornerRadius: AUCDesign.Radius.lg)
    }

    private func minimizedTask(_ task: AUCTaskRecord) -> some View {
        Button {
            if task.status.isTerminal {
                userExpandedTerminalTaskID = task.id
            }
            model.isLauncherCollapsed = false
            isPromptFocused = true
        } label: {
            HStack(spacing: AUCDesign.Space.md) {
                StatusDot(status: task.status)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.displayTitle)
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .lineLimit(1)
                    Text(minimizedSubtitle(for: task))
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(task.status == .completed ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if task.status.isTerminal {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(AUCDesign.FontToken.sans(size: 17, weight: .semibold))
                        .foregroundStyle(statusColor(for: task.status))
                } else {
                    progressTicks(task)
                }
            }
            .padding(.horizontal, AUCDesign.Space.lg)
            .frame(height: AUCDesign.Space.launcherMiniHeight)
            .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .launcherChrome(cornerRadius: 38)
        }
        .buttonStyle(.plain)
    }

    private var pendingTask: some View {
        Button {
            if model.activeTask != nil {
                model.isLauncherCollapsed = false
                isPromptFocused = true
            }
        } label: {
            HStack(spacing: AUCDesign.Space.md) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AUCDesign.ColorToken.violetLight)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.composer.prompt.isEmpty ? model.launcherQuery : model.composer.prompt)
                        .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .lineLimit(1)
                    Text("Starting task")
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.violetLight)
                        .lineLimit(1)
                }

                Spacer()

                progressTicks(done: 1, total: 4)
            }
            .padding(.horizontal, AUCDesign.Space.lg)
            .frame(height: AUCDesign.Space.launcherMiniHeight)
            .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
            .launcherChrome(cornerRadius: 38)
        }
        .buttonStyle(.plain)
    }

    private func taskHeader(_ task: AUCTaskRecord) -> some View {
        HStack(spacing: AUCDesign.Space.sm) {
            StatusDot(status: task.status)
            Text(task.displayTitle)
                .font(AUCDesign.FontToken.sans(size: 15, weight: .semibold))
                .lineLimit(1)

            Text(statusLabel(for: task.status))
                .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                .foregroundStyle(statusColor(for: task.status))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(for: task.status).opacity(0.14))
                .clipShape(Capsule())

            Spacer()

            if !task.todos.isEmpty {
                Text("\(task.todos.filter(\.isDone).count) of \(task.todos.count)")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .padding(.trailing, AUCDesign.Space.sm)
            }

            Button {
                model.isLauncherCollapsed = true
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(LauncherCircleButtonStyle(kind: .plain))
            .help("Minimize")

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(LauncherCircleButtonStyle(kind: .plain))
            .help("Close")
        }
        .padding(.horizontal, AUCDesign.Space.md)
        .frame(height: 52)
    }

    private func runningContent(_ task: AUCTaskRecord) -> some View {
        VStack(spacing: AUCDesign.Space.md) {
            todoList(task)
            if let operation = task.runningFileWriteOperation {
                fileWriteHelpCard(operation)
            }
            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    model.selectTask(task)
                    close()
                } label: {
                    Label("Open full details", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(LauncherSecondaryButtonStyle())

                Button {
                    Task { await model.cancelActiveTask() }
                } label: {
                    Label("Stop task", systemImage: "stop")
                }
                .buttonStyle(LauncherDangerButtonStyle())

                Spacer()
            }
        }
        .padding(AUCDesign.Space.md)
    }

    private func fileWriteHelpCard(_ operation: AUCFileWriteOperation) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            HStack(spacing: AUCDesign.Space.sm) {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(AUCDesign.ColorToken.amber)
                Text("Saving to \(operation.url.deletingLastPathComponent().lastPathComponent)")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                Spacer()
            }
            Text("If macOS is asking for file access, allow AUC Native in Privacy & Security, then retry or stop this task.")
                .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(2)
            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    model.openFileAccessSettings()
                } label: {
                    Label("Open permissions", systemImage: "gearshape")
                }
                .buttonStyle(LauncherSecondaryButtonStyle())

                Button {
                    model.revealDownloadsFolder()
                } label: {
                    Label("Show Downloads", systemImage: "folder")
                }
                .buttonStyle(LauncherSecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AUCDesign.ColorToken.amber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                .stroke(AUCDesign.ColorToken.amber.opacity(0.35), lineWidth: 1)
        }
    }

    private func terminalContent(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                Image(systemName: terminalIcon(for: task.status))
                    .font(AUCDesign.FontToken.sans(size: 25, weight: .medium))
                    .foregroundStyle(statusColor(for: task.status))

                VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                    Text(statusLabel(for: task.status))
                        .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                        .foregroundStyle(statusColor(for: task.status))
                Text(terminalMessage(for: task))
                        .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Spacer()
            }

            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    model.selectTask(task)
                    close()
                } label: {
                    Label("Open full details", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(LauncherSecondaryButtonStyle())

                Button {
                    startNewTaskMode()
                } label: {
                    Label("New task", systemImage: "plus")
                }
                .buttonStyle(LauncherSecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permissionContent(_ request: AUCPermissionRequest) -> some View {
        HStack(alignment: .center, spacing: AUCDesign.Space.lg) {
            ZStack {
                Circle()
                    .fill(AUCDesign.ColorToken.amber.opacity(0.13))
                    .frame(width: 58, height: 58)
                Image(systemName: permissionIcon(for: request))
                    .font(AUCDesign.FontToken.sans(size: 24, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.amber)
            }

            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text(permissionTitle(for: request))
                    .font(AUCDesign.FontToken.sans(size: 17, weight: .semibold))
                Text(permissionMessage(for: request))
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .lineLimit(3)

                HStack(spacing: AUCDesign.Space.sm) {
                    Button(permissionAllowLabel(for: request)) {
                        Task { await model.respondToPermission(request, allowed: true) }
                    }
                    .buttonStyle(LauncherApproveButtonStyle())

                    Button("Deny") {
                        Task { await model.respondToPermission(request, allowed: false) }
                    }
                    .buttonStyle(LauncherSecondaryButtonStyle())
                }
                .padding(.top, AUCDesign.Space.sm)
            }
            Spacer()
        }
        .padding(AUCDesign.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func responseContent(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                Image(systemName: "checkmark.circle")
                    .font(AUCDesign.FontToken.sans(size: 25, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.green)
                VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                    Text("Done")
                        .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.green)
                    Text(responseText(for: task))
                        .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            if !task.artifactURLs.isEmpty {
                HStack(spacing: AUCDesign.Space.sm) {
                    ForEach(task.artifactURLs.prefix(2), id: \.self) { artifact in
                        Button {
                            model.reveal(artifact)
                        } label: {
                            Label(revealLabel(for: artifact), systemImage: "folder")
                        }
                        .buttonStyle(LauncherSecondaryButtonStyle())
                    }
                }
            }
        }
        .padding(AUCDesign.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todoList(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            let todos = task.todos.isEmpty ? fallbackTodos(for: task) : task.todos
            ForEach(Array(todos.prefix(4).enumerated()), id: \.element.id) { index, todo in
                HStack(spacing: AUCDesign.Space.sm) {
                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : (index == todos.filter(\.isDone).count ? "circle.dashed" : "circle"))
                        .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.green : statusColor(for: task.status))
                    Text(todo.content)
                        .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                        .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.textSecondary : AUCDesign.ColorToken.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if index == todos.filter(\.isDone).count, task.status == .running {
                        Text(task.currentAction ?? "Working")
                            .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.violetLight)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(AUCDesign.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AUCDesign.ColorToken.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
        }
    }

    private var followUpBar: some View {
        HStack(spacing: AUCDesign.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)

            TextField(launcherPlaceholder, text: $model.launcherQuery)
                .textFieldStyle(.plain)
                .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                .focused($isPromptFocused)
                .onSubmit(startFromLauncher)

            Button(action: startFromLauncher) {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(LauncherCircleButtonStyle(kind: .primary))
            .keyboardShortcut(.return, modifiers: [])
            .disabled(model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
        }
        .padding(.horizontal, AUCDesign.Space.md)
        .frame(height: 54)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AUCDesign.ColorToken.stroke)
                .frame(height: 1)
        }
    }

    private func startFromLauncher() {
        let prompt = model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !model.isBusy else { return }
        model.composer.prompt = prompt
        model.isLauncherPresented = true
        model.isLauncherCollapsed = true
        resize(true)
        Task {
            await model.submitLauncherPrompt(keepLauncherOpen: true)
            model.isLauncherCollapsed = model.activeTask != nil
            userExpandedTerminalTaskID = nil
            resize(model.isLauncherCollapsed)
            if !model.isLauncherCollapsed {
                isPromptFocused = true
            }
        }
    }

    private func startNewTaskMode() {
        model.activeTaskID = nil
        model.composer.mode = .newTask
        model.composer.prompt = ""
        model.launcherQuery = ""
        model.isLauncherCollapsed = false
        userExpandedTerminalTaskID = nil
        resize(false)
        isPromptFocused = true
    }

    private var launcherPlaceholder: String {
        return "Ask a follow-up..."
    }

    private func fallbackTodos(for task: AUCTaskRecord) -> [AUCTodoItem] {
        [
            AUCTodoItem(id: "\(task.id)-1", content: "Understand request", status: task.status == .queued ? "pending" : "completed"),
            AUCTodoItem(id: "\(task.id)-2", content: task.currentAction ?? "Run task", status: task.status == .running ? "pending" : "completed"),
            AUCTodoItem(id: "\(task.id)-3", content: "Create response", status: task.status == .completed ? "completed" : "pending"),
            AUCTodoItem(id: "\(task.id)-4", content: "Show result", status: task.status == .completed ? "completed" : "pending")
        ]
    }

    private func progressTicks(_ task: AUCTaskRecord) -> some View {
        let done = max(1, task.todos.filter(\.isDone).count)
        let total = max(4, task.todos.count)
        return progressTicks(done: done, total: total)
    }

    private func progressTicks(done: Int, total: Int) -> some View {
        return HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < min(4, done * 4 / total) ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.n300)
                    .frame(width: 10, height: 3)
            }
        }
    }

    private func permissionIcon(for request: AUCPermissionRequest) -> String {
        let text = "\(request.title) \(request.message) \(request.toolName ?? "")"
        if text.localizedCaseInsensitiveContains("mail") {
            return "envelope"
        }
        if text.localizedCaseInsensitiveContains("message") || text.localizedCaseInsensitiveContains("imessage") {
            return "message"
        }
        return "hand.raised.fill"
    }

    private func permissionTitle(for request: AUCPermissionRequest) -> String {
        let text = "\(request.title) \(request.message) \(request.toolName ?? "")"
        if permissionFilePath(for: request) != nil, isWriteCommand(text) {
            return "Create file"
        }
        if request.toolName?.localizedCaseInsensitiveContains("bash") == true ||
            request.title.localizedCaseInsensitiveContains("bash") {
            return "Allow Bash command"
        }
        if text.localizedCaseInsensitiveContains("mail") {
            return "Approve Mail action"
        }
        if text.localizedCaseInsensitiveContains("message") || text.localizedCaseInsensitiveContains("imessage") {
            return "Approve Messages action"
        }
        return request.title
    }

    private func permissionMessage(for request: AUCPermissionRequest) -> String {
        if let file = permissionFilePath(for: request) {
            return "AUC wants to write \(abbreviatedPath(file))."
        }
        return request.message
    }

    private func permissionAllowLabel(for request: AUCPermissionRequest) -> String {
        let text = "\(request.title) \(request.message) \(request.toolName ?? "")"
        if permissionFilePath(for: request) != nil, isWriteCommand(text) {
            return "Create file"
        }
        if request.toolName?.localizedCaseInsensitiveContains("bash") == true ||
            request.title.localizedCaseInsensitiveContains("bash") {
            return "Allow command"
        }
        return "Approve"
    }

    private func permissionFilePath(for request: AUCPermissionRequest) -> String? {
        if let filePath = request.filePath, !filePath.isEmpty {
            return filePath
        }
        if let first = request.filePaths.first, !first.isEmpty {
            return first
        }
        let message = request.message
        if let match = message.firstMatch(of: /(?:\$HOME|~|\/Users\/[^\s"'\\]+)\/[^\s"'\\]+/) {
            return String(match.output)
        }
        return nil
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path
            .replacingOccurrences(of: "$HOME", with: "~")
            .replacingOccurrences(of: home, with: "~")
    }

    private func isWriteCommand(_ text: String) -> Bool {
        text.contains(" > ") ||
            text.contains(">>") ||
            text.localizedCaseInsensitiveContains("write") ||
            text.localizedCaseInsensitiveContains("create")
    }

    private func minimizedSubtitle(for task: AUCTaskRecord) -> String {
        if task.status == .completed {
            return responseText(for: task)
        }
        if task.status == .failed {
            return task.result?.error ?? task.currentAction ?? "Needs attention"
        }
        return task.currentAction ?? statusLabel(for: task.status)
    }

    private func terminalIcon(for status: AUCTaskStatus) -> String {
        switch status {
        case .cancelled, .interrupted:
            return "minus.circle"
        case .failed:
            return "exclamationmark.circle"
        default:
            return "circle"
        }
    }

    private func terminalMessage(for task: AUCTaskRecord) -> String {
        if let error = task.result?.error, !error.isEmpty {
            return error
        }
        switch task.status {
        case .cancelled:
            return "This task was cancelled. Type below to continue the same task, or click New task to start fresh."
        case .interrupted:
            return "This task was stopped. Type below to continue the same task, or click New task to start fresh."
        case .failed:
            return task.currentAction ?? "This task failed. Type below to continue the same task, or click New task to start fresh."
        default:
            return task.currentAction ?? "Type below to continue this task."
        }
    }

    private func responseText(for task: AUCTaskRecord) -> String {
        if let latest = task.messages.last(where: { $0.type == "assistant" && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return latest.content
        }
        if let summary = task.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        if let artifact = task.artifactURLs.first {
            return "Saved \(artifact.lastPathComponent)."
        }
        if let status = task.result?.status, !status.isEmpty {
            return status
        }
        return "Completed."
    }

    private func revealLabel(for url: URL) -> String {
        let name = url.lastPathComponent
        guard !name.isEmpty else { return "Reveal result" }
        return name.count > 28 ? "Reveal result" : "Reveal \(name)"
    }

    private func statusLabel(for status: AUCTaskStatus) -> String {
        switch status {
        case .queued: "Queued"
        case .running: "Running"
        case .waitingPermission: "Permission needed"
        case .completed: "Done"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .interrupted: "Stopped"
        case .unknown: "Working"
        }
    }

    private func statusColor(for status: AUCTaskStatus) -> Color {
        switch status {
        case .completed: AUCDesign.ColorToken.green
        case .running: AUCDesign.ColorToken.violetLight
        case .queued, .waitingPermission: AUCDesign.ColorToken.amber
        case .failed: AUCDesign.ColorToken.red
        case .cancelled, .interrupted, .unknown: AUCDesign.ColorToken.textSecondary
        }
    }
}

private enum LauncherCircleButtonKind {
    case primary
    case plain
}

private struct LauncherCircleButtonStyle: ButtonStyle {
    let kind: LauncherCircleButtonKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 16, weight: .semibold))
            .frame(width: kind == .primary ? 42 : 32, height: kind == .primary ? 42 : 32)
            .background(background(configuration))
            .foregroundStyle(kind == .primary ? Color.white : AUCDesign.ColorToken.textSecondary)
            .clipShape(Circle())
            .shadow(
                color: kind == .primary ? AUCDesign.ColorToken.violet.opacity(configuration.isPressed ? 0.20 : 0.40) : .clear,
                radius: 18,
                y: 6
            )
    }

    private func background(_ configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet
        case .plain:
            return configuration.isPressed ? AUCDesign.ColorToken.panelStrong : Color.clear
        }
    }
}

private struct LauncherSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? AUCDesign.ColorToken.panelStrong : AUCDesign.ColorToken.panel.opacity(0.7))
            .foregroundStyle(AUCDesign.ColorToken.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.sm, style: .continuous)
                    .stroke(AUCDesign.ColorToken.strokeStrong, lineWidth: 1)
            }
    }
}

private struct LauncherDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.vertical, 9)
            .background(AUCDesign.ColorToken.red.opacity(configuration.isPressed ? 0.18 : 0.08))
            .foregroundStyle(AUCDesign.ColorToken.red)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.sm, style: .continuous)
                    .stroke(AUCDesign.ColorToken.red.opacity(0.65), lineWidth: 1)
            }
    }
}

private struct LauncherApproveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
            .padding(.horizontal, AUCDesign.Space.lg)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.sm, style: .continuous))
            .aucShadow(AUCDesign.Shadow.aucGlow)
    }
}

private extension View {
    func launcherChrome(cornerRadius: CGFloat) -> some View {
        self
            .background(
                ZStack {
                    AUCDesign.ColorToken.card.opacity(0.90)
                    LinearGradient(
                        colors: [Color.white.opacity(0.075), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AUCDesign.ColorToken.strokeStrong, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.45), radius: 42, y: 22)
            .shadow(color: AUCDesign.ColorToken.violet.opacity(0.24), radius: 34, y: 14)
    }
}
