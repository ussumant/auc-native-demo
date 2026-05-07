import AUCNativeCore
import SwiftUI

struct TaskLauncherView: View {
    @Bindable var model: AUCAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let activeTask = model.activeTask {
                activeHeader(activeTask)
            }

            searchBar

            Divider()
                .overlay(AUCDesign.ColorToken.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                    Button {
                        startFromLauncher()
                    } label: {
                        HStack(spacing: AUCDesign.Space.sm) {
                            Image(systemName: model.activeTask == nil ? "plus" : "paperplane.fill")
                            Text(model.activeTask == nil ? "New task" : "Send follow-up")
                            if !model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("\"\(model.launcherQuery)\"")
                                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(LauncherRowButtonStyle(isSelected: true))
                    .disabled(model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)

                    if let error = model.errorMessage {
                        LauncherNotice(text: error, systemImage: "exclamationmark.triangle.fill", color: AUCDesign.ColorToken.amber)
                            .padding(.horizontal, AUCDesign.Space.md)
                    } else if model.isBusy {
                        LauncherNotice(text: "Starting task with the bundled executor...", systemImage: "circle.dotted", color: AUCDesign.ColorToken.violetLight)
                            .padding(.horizontal, AUCDesign.Space.md)
                    }

                    if !model.visibleLauncherTasks.isEmpty {
                        Text(model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Last seven days" : "Results")
                            .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                            .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                            .padding(.horizontal, AUCDesign.Space.md)
                            .padding(.top, AUCDesign.Space.sm)

                        ForEach(model.visibleLauncherTasks) { task in
                            Button {
                                model.selectTask(task)
                                dismiss()
                            } label: {
                                LauncherTaskRow(task: task)
                            }
                            .buttonStyle(LauncherRowButtonStyle(isSelected: false))
                        }
                    } else if !model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No tasks found")
                            .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AUCDesign.Space.xl)
                    }
                }
                .padding(AUCDesign.Space.md)
            }

            footer
        }
        .background(AUCDesign.ColorToken.void)
        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
    }

    private var searchBar: some View {
        HStack(spacing: AUCDesign.Space.sm) {
            Image(systemName: model.activeTask?.status == .running ? "circle.dotted" : "magnifyingglass")
                .foregroundStyle(model.activeTask?.status == .running ? AUCDesign.ColorToken.violetLight : AUCDesign.ColorToken.textTertiary)
            TextField(model.activeTask == nil ? "Search tasks or start a new one" : "Ask a follow-up...", text: $model.launcherQuery)
                .textFieldStyle(.plain)
                .font(AUCDesign.FontToken.sans(size: 15, weight: .medium))
            Button {
                startFromLauncher()
            } label: {
                Image(systemName: model.activeTask == nil ? "plus" : "paperplane.fill")
            }
            .buttonStyle(SubmitMiniButtonStyle())
            .disabled(model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.panel)
    }

    private func activeHeader(_ task: AUCTaskRecord) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
            HStack(spacing: AUCDesign.Space.sm) {
                StatusDot(status: task.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.displayTitle)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(task.currentAction ?? "Ready")
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    model.activeTaskID = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Detach task")
            }

            if let request = model.permissionRequest, request.taskID == task.id {
                permissionCard(request)
            }

            if !task.todos.isEmpty {
                HStack(spacing: AUCDesign.Space.xs) {
                    Image(systemName: "checklist")
                    Text("\(task.todos.filter(\.isDone).count)/\(task.todos.count) todos")
                    Spacer()
                }
                .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            }
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.card)
    }

    private func permissionCard(_ request: AUCPermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            Label(request.title, systemImage: "exclamationmark.triangle.fill")
                .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.amber)
            Text(request.message)
                .font(AUCDesign.FontToken.sans(size: 12))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(3)
            HStack {
                Button("Allow") {
                    Task { await model.respondToPermission(request, allowed: true) }
                }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Deny") {
                    Task { await model.respondToPermission(request, allowed: false) }
                }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(AUCDesign.Space.md)
        .background(AUCDesign.ColorToken.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                .stroke(AUCDesign.ColorToken.amber.opacity(0.30), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack(spacing: AUCDesign.Space.md) {
            KeyHint(keys: "up/down", label: "navigate")
            KeyHint(keys: "return", label: "select")
            KeyHint(keys: "opt+b", label: "launcher")
            KeyHint(keys: "esc", label: "close")
            Spacer()
        }
        .padding(.horizontal, AUCDesign.Space.md)
        .padding(.vertical, AUCDesign.Space.sm)
        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AUCDesign.ColorToken.stroke)
                .frame(height: 1)
        }
    }

    private func startFromLauncher() {
        let prompt = model.launcherQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        Task {
            await model.submitLauncherPrompt(keepLauncherOpen: false)
            if model.errorMessage == nil {
                dismiss()
            }
        }
    }
}

private struct LauncherNotice: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AUCDesign.Space.sm)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: 1)
            }
    }
}

private struct LauncherTaskRow: View {
    let task: AUCTaskRecord

    var body: some View {
        HStack(spacing: AUCDesign.Space.md) {
            StatusDot(status: task.status)
            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text(task.displayTitle)
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(task.prompt)
                    .font(AUCDesign.FontToken.sans(size: 12))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(task.status.rawValue.replacingOccurrences(of: "_", with: " "))
                .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textTertiary)
        }
    }
}

private struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: AUCDesign.Space.xs) {
            Text(keys)
                .font(AUCDesign.FontToken.sans(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(AUCDesign.ColorToken.panel)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(label)
                .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
        }
    }
}

private struct LauncherRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.vertical, 11)
            .background(rowBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
            .foregroundStyle(isSelected ? .white : AUCDesign.ColorToken.textPrimary)
            .shadow(color: isSelected ? AUCDesign.ColorToken.violet.opacity(0.28) : .clear, radius: 9)
    }

    private func rowBackground(_ configuration: Configuration) -> Color {
        if isSelected {
            return configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet
        }
        return configuration.isPressed ? AUCDesign.ColorToken.panelStrong : Color.clear
    }
}

private struct SubmitMiniButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet)
            .foregroundStyle(.white)
            .clipShape(Circle())
            .shadow(color: AUCDesign.ColorToken.violet.opacity(0.28), radius: 9)
    }
}
