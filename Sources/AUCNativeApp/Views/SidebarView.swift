import AUCNativeCore
import SwiftUI

struct SidebarView: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AUCDesign.Space.md) {
                workspaceHeader

                VStack(spacing: AUCDesign.Space.sm) {
                    Button {
                        model.composer.mode = .newTask
                        model.composer.prompt = ""
                        model.activeTaskID = nil
                    } label: {
                        Label("New task", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        model.isLauncherPresented = true
                    } label: {
                        HStack(spacing: AUCDesign.Space.sm) {
                            Image(systemName: "magnifyingglass")
                            Text("Launcher")
                            Spacer()
                            Text("Option+B")
                                .font(AUCDesign.FontToken.sans(size: 10, weight: .bold))
                                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AUCDesign.ColorToken.panelStrong)
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Open launcher with Option-B")
                }
            }
            .padding(.horizontal, AUCDesign.Space.md)
            .padding(.top, 54)
            .padding(.bottom, AUCDesign.Space.md)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AUCDesign.ColorToken.stroke)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                    Text("History")
                        .font(AUCDesign.FontToken.sans(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                        .padding(.horizontal, AUCDesign.Space.sm)
                        .padding(.top, AUCDesign.Space.md)

                    if model.tasks.isEmpty {
                        Text("No conversations yet")
                            .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                            .foregroundStyle(AUCDesign.ColorToken.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AUCDesign.Space.xl)
                    } else {
                        LazyVStack(spacing: AUCDesign.Space.xs) {
                            ForEach(model.tasks) { task in
                                Button {
                                    model.selectTask(task)
                                } label: {
                                    SidebarTaskRow(task: task, isActive: task.id == model.activeTaskID)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AUCDesign.Space.sm)
            }

            bottomBar
        }
        .background(AUCDesign.ColorToken.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AUCDesign.ColorToken.stroke)
                .frame(width: 1)
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: AUCDesign.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(AUCDesign.ColorToken.violet.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(AUCDesign.FontToken.sans(size: 14, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.violetLight)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("auc")
                    .font(AUCDesign.FontToken.sans(size: 16, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                Text("Tasks")
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            }

            Spacer()

            Circle()
                .fill(model.isExecutorConnected ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                .frame(width: 8, height: 8)
                .shadow(color: (model.isExecutorConnected ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber).opacity(0.5), radius: 6)
        }
        .padding(.horizontal, AUCDesign.Space.sm)
        .padding(.vertical, 10)
        .background(AUCDesign.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: AUCDesign.Space.sm) {
            ExecutorRepairCard(model: model)

            HStack(spacing: AUCDesign.Space.sm) {
                Text("AUC")
                    .font(AUCDesign.FontToken.sans(size: 15, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary.opacity(0.92))

                Spacer()

                Button {
                    model.isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Settings")
            }
        }
        .padding(AUCDesign.Space.md)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AUCDesign.ColorToken.stroke)
                .frame(height: 1)
        }
    }
}

private struct SidebarTaskRow: View {
    let task: AUCTaskRecord
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AUCDesign.Space.sm) {
            StatusDot(status: task.status)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: AUCDesign.Space.xs) {
                Text(task.displayTitle)
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .medium))
                    .lineLimit(2)
                Text(task.status.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(AUCDesign.FontToken.sans(size: 11, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AUCDesign.Space.sm)
        .padding(.vertical, 10)
        .background(isActive ? AUCDesign.ColorToken.panelStrong : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                    .stroke(AUCDesign.ColorToken.violet.opacity(0.35), lineWidth: 1)
            }
        }
    }
}

private struct ExecutorRepairCard: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            HStack {
                Image(systemName: model.isExecutorConnected ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(model.isExecutorConnected ? AUCDesign.ColorToken.green : AUCDesign.ColorToken.amber)
                Text(model.isExecutorConnected ? "Executor ready" : "Executor needs repair")
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
            }
            if let error = model.errorMessage, !model.isExecutorConnected {
                Text(error)
                    .font(AUCDesign.FontToken.sans(size: 11))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(AUCDesign.Space.sm)
        .background(AUCDesign.ColorToken.panel)
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.md, style: .continuous)
                .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
    }
}
}
