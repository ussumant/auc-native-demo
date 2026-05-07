import AUCNativeCore
import SwiftUI

struct ActiveTaskView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.sm) {
                Text("Active")
                    .font(AUCDesign.FontToken.sans(size: 15, weight: .semibold))
                Spacer()
                Button {
                    model.isLauncherPresented = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Open launcher")
                Button {
                    Task { await model.cancelActiveTask() }
                } label: {
                    Image(systemName: "stop")
                }
                .buttonStyle(IconCircleButtonStyle())
                .disabled(model.activeTask?.status.isTerminal ?? true)
                .help("Stop task")
            }
            .padding(.top, 54)

            ScrollView {
                VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                    if let task = model.activeTask {
                        activeTaskCard(task)
                        if let request = model.permissionRequest, request.taskID == task.id {
                            permissionCard(request)
                        }
                        if !task.todos.isEmpty {
                            todoCard(task.todos)
                        }
                        if let frame = task.browserFrame {
                            browserFrameCard(frame)
                        }
                        if !task.messages.isEmpty {
                            messageTimeline(task.messages)
                        }
                        proofCard(task)
                    } else {
                        emptyState
                    }
                }
                .padding(.bottom, AUCDesign.Space.md)
            }
            .scrollIndicators(.hidden)

            followUpComposer
        }
        .padding(.horizontal, AUCDesign.Space.md)
        .padding(.bottom, AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.void.opacity(0.96))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AUCDesign.ColorToken.stroke)
                .frame(width: 1)
        }
    }

    private func activeTaskCard(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.sm) {
                StatusDot(status: task.status)
                Text(format(task.status))
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                Spacer()
                Text(task.createdAt, style: .time)
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
            }

            Text(task.displayTitle)
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                .lineLimit(4)

            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text(task.status.isTerminal ? "Latest output" : "Current action")
                    .font(AUCDesign.FontToken.sans(size: 10, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                Text(task.currentAction ?? currentAction(for: task.status))
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                    .lineLimit(3)
            }
            .padding(AUCDesign.Space.md)
            .background(AUCDesign.ColorToken.void.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel(cornerRadius: AUCDesign.Radius.lg)
    }

    private func proofCard(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack {
                Image(systemName: task.status == .completed ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
                    .foregroundStyle(task.status == .completed ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.violetLight)
                Text(task.status == .completed ? "Proof" : "Working proof")
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
            }

            Text(proofText(for: task))
                .font(AUCDesign.FontToken.sans(size: 12))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(5)

            ForEach(task.artifactURLs, id: \.self) { url in
                Button {
                    model.reveal(url)
                } label: {
                    Label(url.lastPathComponent, systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel()
    }

    private func permissionCard(_ request: AUCPermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.sm) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(AUCDesign.ColorToken.amber)
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.title)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                    Text(request.type.capitalized)
                        .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                }
                Spacer()
            }

            Text(request.message)
                .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(6)

            if !request.options.isEmpty {
                Text(request.options.joined(separator: " / "))
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
                    .lineLimit(2)
            }

            HStack {
                Button {
                    Task { await model.respondToPermission(request, allowed: true) }
                } label: {
                    Label("Allow", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Task { await model.respondToPermission(request, allowed: false) }
                } label: {
                    Label("Deny", systemImage: "xmark")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                .stroke(AUCDesign.ColorToken.amber.opacity(0.34), lineWidth: 1)
        }
    }

    private func todoCard(_ todos: [AUCTodoItem]) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            Label("Todos", systemImage: "checklist")
                .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
            ForEach(todos.prefix(5)) { todo in
                HStack(spacing: AUCDesign.Space.sm) {
                    Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.textTertiary)
                    Text(todo.content)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.textTertiary : AUCDesign.ColorToken.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel()
    }

    private func browserFrameCard(_ frame: AUCBrowserFrame) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            HStack {
                Label("Browser", systemImage: "safari")
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                Spacer()
                if let url = frame.url, !url.isEmpty {
                    Text(url)
                        .font(AUCDesign.FontToken.sans(size: 10, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                        .lineLimit(1)
                }
            }
            Text(frame.title ?? frame.summary ?? "Live browser frame received")
                .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(3)
            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                .fill(AUCDesign.ColorToken.panelStrong)
                .frame(height: 118)
                .overlay {
                    VStack(spacing: AUCDesign.Space.xs) {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(AUCDesign.ColorToken.violetLight)
                        Text(frame.imageData == nil ? "Preview metadata" : "Preview frame available")
                            .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
                            .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    }
                }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel()
    }

    private func messageTimeline(_ messages: [AUCTaskMessage]) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            Label("Timeline", systemImage: "list.bullet.rectangle")
                .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
            ForEach(messages.suffix(6)) { message in
                HStack(alignment: .top, spacing: AUCDesign.Space.sm) {
                    Image(systemName: icon(for: message))
                        .frame(width: 18)
                        .foregroundStyle(color(for: message))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(message.toolName ?? message.type.capitalized)
                            .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                            .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                        Text(message.content.isEmpty ? (message.toolInputDescription ?? message.toolStatus ?? "Working") : message.content)
                            .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                            .lineLimit(4)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack {
                Image(systemName: "circle.dashed")
                    .font(AUCDesign.FontToken.sans(size: 24, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
                Spacer()
                Text("Ready")
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
            }
            Text("No active task")
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
            Text("Start from the main composer, or search recent tasks with the launcher.")
                .font(AUCDesign.FontToken.sans(size: 12))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
        }
        .padding(AUCDesign.Space.md)
        .aucPanel(cornerRadius: AUCDesign.Radius.lg)
    }

    private var followUpComposer: some View {
        Button {
            model.startFollowUp()
        } label: {
            HStack(spacing: AUCDesign.Space.sm) {
                Image(systemName: "paperplane")
                Text(model.activeTask == nil ? "Follow-up unavailable" : "Ask a follow-up...")
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(model.activeTask == nil)
    }

    private func format(_ status: AUCTaskStatus) -> String {
        switch status {
        case .queued: "Queued"
        case .running: "Running"
        case .waitingPermission: "Waiting"
        case .completed: "Done"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .interrupted: "Stopped"
        case .unknown: "Unknown"
        }
    }

    private func currentAction(for status: AUCTaskStatus) -> String {
        switch status {
        case .queued: "Waiting to start"
        case .running: "Working through the bundled executor"
        case .waitingPermission: "Waiting for permission"
        case .completed: "Done with proof"
        case .failed: "Needs attention"
        case .cancelled: "Cancelled"
        case .interrupted: "Stopped, ready for follow-up"
        case .unknown: "Awaiting daemon update"
        }
    }

    private func proofText(for task: AUCTaskRecord) -> String {
        if let error = task.result?.error, !error.isEmpty {
            return error
        }
        if task.status == .completed {
            return task.artifactURLs.isEmpty ? "Completed. No artifact proof was reported by the daemon yet." : "Completed with artifacts ready to reveal."
        }
        return "Progress, permission, and artifact events will appear here as the daemon reports them."
    }

    private func icon(for message: AUCTaskMessage) -> String {
        switch message.type {
        case "tool": message.toolStatus == "completed" ? "checkmark.circle.fill" : "wrench.and.screwdriver"
        case "assistant": "sparkles"
        case "user": "person.crop.circle"
        default: "smallcircle.filled.circle"
        }
    }

    private func color(for message: AUCTaskMessage) -> Color {
        if message.toolStatus == "error" { return AUCDesign.ColorToken.red }
        if message.toolStatus == "completed" { return AUCDesign.ColorToken.green }
        if message.type == "tool" { return AUCDesign.ColorToken.cyan }
        return AUCDesign.ColorToken.violetLight
    }
}
