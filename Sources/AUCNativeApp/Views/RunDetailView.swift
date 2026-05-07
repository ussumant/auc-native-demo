import AUCNativeCore
import SwiftUI

struct RunDetailView: View {
    @Bindable var model: AUCAppModel
    let task: AUCTaskRecord

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 240)
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: AUCDesign.Space.lg) {
                    header

                    if let request = model.permissionRequest, request.taskID == task.id {
                        permissionCard(request)
                    }

                    if !task.todos.isEmpty {
                        todosSection
                    }

                    if let frame = task.browserFrame {
                        browserSection(frame)
                    }

                    outputSection
                    timelineSection
                    proofSection
                }
                .padding(.horizontal, AUCDesign.Space.xl)
                .padding(.top, 72)
                .padding(.bottom, 150)
                .frame(maxWidth: AUCDesign.Space.runDetailMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(AUCDesign.ColorToken.void)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(alignment: .top, spacing: AUCDesign.Space.md) {
                StatusDot(status: task.status)
                    .padding(.top, 10)
                VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                    HStack(spacing: AUCDesign.Space.sm) {
                        Text(statusLabel)
                            .font(AUCDesign.FontToken.sans(size: 12, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(statusColor)
                        Text(task.createdAt, style: .time)
                            .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                            .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    }

                    Text(task.displayTitle)
                        .font(AUCDesign.FontToken.sans(size: 34, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(task.prompt)
                        .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AUCDesign.Space.md)

                HStack(spacing: AUCDesign.Space.sm) {
                    Button {
                        model.composer.mode = .newTask
                        model.composer.prompt = ""
                        model.activeTaskID = nil
                    } label: {
                        Label("New", systemImage: "plus")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(minWidth: 92)

                    Button {
                        model.startFollowUp()
                    } label: {
                        Label("Follow up", systemImage: "paperplane")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(minWidth: 124)

                    Button {
                        Task { await model.cancelActiveTask() }
                    } label: {
                        Image(systemName: "stop")
                    }
                    .buttonStyle(IconCircleButtonStyle())
                    .disabled(task.status.isTerminal)
                    .help("Stop task")
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            }

            if let current = task.currentAction, !current.isEmpty {
                HStack(alignment: .top, spacing: AUCDesign.Space.sm) {
                    Image(systemName: task.status.isTerminal ? "text.quote" : "circle.dotted")
                        .foregroundStyle(statusColor)
                    Text(current)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AUCDesign.Space.md)
                .background(AUCDesign.ColorToken.panel)
                .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                        .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
                }
            }
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle("Output", systemImage: "text.bubble")

            if let latest = latestAssistantMessage {
                RunMessageCard(message: latest, isExpanded: true)
            } else if let result = task.result {
                Text(result.error ?? result.status)
                    .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AUCDesign.Space.lg)
                    .aucPanel()
            } else {
                Text("No assistant output has been reported yet.")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AUCDesign.Space.lg)
                    .aucPanel()
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle("Full Run", systemImage: "list.bullet.rectangle")

            if task.messages.isEmpty {
                Text("The daemon has not emitted message events for this run yet.")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AUCDesign.Space.lg)
                    .aucPanel()
            } else {
                VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                    ForEach(task.messages) { message in
                        RunMessageCard(message: message, isExpanded: true)
                    }
                }
            }
        }
    }

    private var todosSection: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle("Todos", systemImage: "checklist")

            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                ForEach(task.todos) { todo in
                    HStack(alignment: .top, spacing: AUCDesign.Space.sm) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.textTertiary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(todo.content)
                                .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                                .foregroundStyle(todo.isDone ? AUCDesign.ColorToken.textTertiary : AUCDesign.ColorToken.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(todo.status.replacingOccurrences(of: "_", with: " ")) · \(todo.priority)")
                                .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                                .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(AUCDesign.Space.sm)
                    .background(AUCDesign.ColorToken.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                }
            }
            .padding(AUCDesign.Space.md)
            .aucPanel()
        }
    }

    private func browserSection(_ frame: AUCBrowserFrame) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle("Browser", systemImage: "safari")
            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                Text(frame.title ?? frame.summary ?? "Browser frame received")
                    .font(AUCDesign.FontToken.sans(size: 16, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                if let url = frame.url {
                    Text(url)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .textSelection(.enabled)
                }
                RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                    .fill(AUCDesign.ColorToken.panelStrong)
                    .frame(height: 260)
                    .overlay {
                        VStack(spacing: AUCDesign.Space.sm) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(AUCDesign.FontToken.sans(size: 24, weight: .semibold))
                                .foregroundStyle(AUCDesign.ColorToken.violetLight)
                            Text(frame.imageData == nil ? "Preview metadata available" : "Preview frame available")
                                .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        }
                    }
            }
            .padding(AUCDesign.Space.lg)
            .aucPanel()
        }
    }

    private var proofSection: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle(task.status == .completed ? "Proof" : "Working Proof", systemImage: task.status == .completed ? "checkmark.seal.fill" : "doc.text.magnifyingglass")
            VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                Text(proofText)
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

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
            .padding(AUCDesign.Space.lg)
            .aucPanel()
        }
    }

    private func permissionCard(_ request: AUCPermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            sectionTitle("Permission Needed", systemImage: "hand.raised.fill")
            Text(request.title)
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
            Text(request.message)
                .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

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
        .padding(AUCDesign.Space.lg)
        .background(AUCDesign.ColorToken.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                .stroke(AUCDesign.ColorToken.amber.opacity(0.34), lineWidth: 1)
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: AUCDesign.Space.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AUCDesign.ColorToken.violetLight)
            Text(title)
                .font(AUCDesign.FontToken.sans(size: 18, weight: .semibold))
            Spacer()
        }
    }

    private var latestAssistantMessage: AUCTaskMessage? {
        task.messages.last { $0.type == "assistant" && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var statusLabel: String {
        switch task.status {
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

    private var statusColor: Color {
        switch task.status {
        case .completed: AUCDesign.ColorToken.green
        case .running: AUCDesign.ColorToken.cyan
        case .waitingPermission, .queued: AUCDesign.ColorToken.amber
        case .failed: AUCDesign.ColorToken.red
        case .cancelled, .interrupted, .unknown: AUCDesign.ColorToken.textSecondary
        }
    }

    private var proofText: String {
        if let error = task.result?.error, !error.isEmpty {
            return error
        }
        if task.status == .completed {
            return task.artifactURLs.isEmpty ? "Completed. No artifact proof was reported by the daemon yet." : "Completed with artifacts ready to reveal."
        }
        return "Progress, permission, and artifact events will appear here as the daemon reports them."
    }
}

private struct RunMessageCard: View {
    let message: AUCTaskMessage
    let isExpanded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AUCDesign.Space.md) {
            Image(systemName: icon)
                .font(AUCDesign.FontToken.sans(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                HStack(spacing: AUCDesign.Space.sm) {
                    Text(message.toolName ?? message.type.capitalized)
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .bold))
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                    if let status = message.toolStatus {
                        Text(status)
                            .font(AUCDesign.FontToken.sans(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    Text(message.timestamp, style: .time)
                        .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                }

                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.content)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .textSelection(.enabled)
                        .lineLimit(isExpanded ? nil : 4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let input = message.toolInputDescription, !input.isEmpty {
                    Text(input)
                        .font(AUCDesign.FontToken.mono(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                        .textSelection(.enabled)
                        .lineLimit(isExpanded ? nil : 5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(AUCDesign.Space.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AUCDesign.ColorToken.void.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
                }
            }
        }
        .padding(AUCDesign.Space.md)
        .aucPanel()
    }

    private var icon: String {
        switch message.type {
        case "tool": message.toolStatus == "completed" ? "checkmark.circle.fill" : "wrench.and.screwdriver"
        case "assistant": "sparkles"
        case "user": "person.crop.circle"
        default: "smallcircle.filled.circle"
        }
    }

    private var color: Color {
        if message.toolStatus == "error" { return AUCDesign.ColorToken.red }
        if message.toolStatus == "completed" { return AUCDesign.ColorToken.green }
        if message.type == "tool" { return AUCDesign.ColorToken.cyan }
        return AUCDesign.ColorToken.violetLight
    }
}
