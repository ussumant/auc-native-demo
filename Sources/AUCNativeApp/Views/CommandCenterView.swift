import AUCNativeCore
import SwiftUI
import UniformTypeIdentifiers

struct CommandCenterView: View {
    @Bindable var model: AUCAppModel
    @State private var isFileImporterPresented = false
    @State private var isFolderImporterPresented = false

    var body: some View {
        if let task = model.activeTask, shouldShowRunDetail(for: task) {
            RunDetailView(model: model, task: task)
        } else {
            homeComposer
        }
    }

    private func shouldShowRunDetail(for task: AUCTaskRecord) -> Bool {
        model.composer.mode == .newTask || model.isBusy || !task.status.isTerminal
    }

    private var homeComposer: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.045), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 280)
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: AUCDesign.Space.lg) {
                    Spacer(minLength: 196)

                    Text(model.composer.mode == .newTask ? "What should AUC do?" : "Ask a follow-up")
                        .font(AUCDesign.FontToken.sans(size: 32, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity)

                    composerBox
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)

                    if let error = model.errorMessage {
                        StatusBanner(
                            title: "Task could not start",
                            message: error,
                            systemImage: "exclamationmark.triangle.fill",
                            color: AUCDesign.ColorToken.amber
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    } else if model.isBusy {
                        StatusBanner(
                            title: "Starting task",
                            message: "AUC is handing this to the bundled executor.",
                            systemImage: "circle.dotted",
                            color: AUCDesign.ColorToken.violetLight
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    } else if model.executorPhase == .starting || model.executorPhase == .repairing {
                        StatusBanner(
                            title: model.executorPhase == .repairing ? "Repairing executor" : "Starting executor",
                            message: "AUC is preparing the bundled runtime before checking provider setup.",
                            systemImage: "circle.dotted",
                            color: AUCDesign.ColorToken.violetLight
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    } else if model.executorPhase == .crashed {
                        StatusBanner(
                            title: "Executor crashed",
                            message: "Use Repair executor. Diagnostics includes the latest daemon runtime error.",
                            systemImage: "exclamationmark.octagon.fill",
                            color: AUCDesign.ColorToken.amber
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    } else if model.executorPhase == .failed {
                        StatusBanner(
                            title: "Executor needs repair",
                            message: "Use Repair executor in the sidebar or Settings, then start the task again.",
                            systemImage: "wrench.and.screwdriver.fill",
                            color: AUCDesign.ColorToken.amber
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    } else if model.executorPhase.isReadyForProviderSetup && !model.providerSettings.hasReadyProvider {
                        StatusBanner(
                            title: "Provider setup needed",
                            message: "Add your OpenAI key in Settings before starting tasks.",
                            systemImage: "key.fill",
                            color: AUCDesign.ColorToken.amber
                        )
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    }

                    if let folder = model.composer.workingDirectory {
                        workingDirectoryRow(folder)
                            .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                    }

                    favoritesSection
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)

                    examplesSection
                        .frame(maxWidth: AUCDesign.Space.commandMaxWidth)
                        .padding(.top, AUCDesign.Space.xl)
                        .padding(.bottom, 140)
                }
                .padding(.horizontal, AUCDesign.Space.xl)
            }
        }
        .background(AUCDesign.ColorToken.background)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls.prefix(8) {
                    model.addAttachment(url)
                }
            }
        }
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.setWorkingDirectory(url)
            }
        }
    }

    private var composerBox: some View {
        VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
            TextField("Assign a task or ask anything", text: $model.composer.prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AUCDesign.FontToken.sans(size: 17, weight: .regular))
                .lineLimit(3...7)
                .padding(.horizontal, AUCDesign.Space.md)
                .padding(.top, AUCDesign.Space.md)
                .padding(.bottom, model.composer.attachments.isEmpty ? AUCDesign.Space.sm : 0)

            if !model.composer.attachments.isEmpty {
                FlowRow {
                    ForEach(model.composer.attachments) { attachment in
                        Chip(label: attachment.displayName, systemImage: "paperclip")
                    }
                }
                .padding(.horizontal, AUCDesign.Space.md)
                .padding(.bottom, AUCDesign.Space.sm)
            }

            HStack(spacing: AUCDesign.Space.sm) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Add files or folders")

                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "paperclip")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Attach files")

                Button {
                    isFolderImporterPresented = true
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(IconCircleButtonStyle())
                .help("Set working folder")

                Spacer()

                ModelIndicator(model: model)

                Button {} label: {
                    Image(systemName: "mic")
                }
                .buttonStyle(IconCircleButtonStyle())
                .disabled(true)
                .help("Voice input slot")

                Button {
                    Task { await model.submitComposer() }
                } label: {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: model.composer.mode == .newTask ? "arrow.up" : "paperplane.fill")
                            .font(AUCDesign.FontToken.sans(size: 15, weight: .bold))
                    }
                }
                .buttonStyle(SubmitCircleButtonStyle())
                .disabled(!model.composer.canSubmit || model.isBusy)
                .help(model.composer.mode == .newTask ? "Start task" : "Send follow-up")
            }
            .padding(.horizontal, AUCDesign.Space.sm)
            .padding(.bottom, AUCDesign.Space.sm)
        }
        .background(AUCDesign.ColorToken.card.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                .stroke(AUCDesign.ColorToken.strokeStrong, lineWidth: 1)
        }
        .aucShadow(AUCDesign.Shadow.aucGlow)
    }

    private func workingDirectoryRow(_ folder: URL) -> some View {
        HStack(spacing: AUCDesign.Space.xs) {
            Image(systemName: "folder")
            Text("Folder: \(folder.lastPathComponent)")
                .lineLimit(1)
            Button {
                model.composer.workingDirectory = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AUCDesign.Space.sm)
    }

    private var favoritesSection: some View {
        VStack(spacing: AUCDesign.Space.md) {
            Text("Favorites")
                .font(AUCDesign.FontToken.sans(size: 18, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textPrimary)

            if model.tasks.isEmpty {
                Text("Favorite completed tasks will appear here.")
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .regular))
                    .foregroundStyle(AUCDesign.ColorToken.textTertiary)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: AUCDesign.Space.md), count: 3),
                    spacing: AUCDesign.Space.md
                ) {
                    ForEach(Array(model.tasks.prefix(3))) { task in
                        PromptCard(title: task.displayTitle, subtitle: task.status.rawValue.replacingOccurrences(of: "_", with: " ")) {
                            model.selectTask(task)
                        }
                    }
                }
            }
        }
    }

    private var examplesSection: some View {
        VStack(spacing: AUCDesign.Space.md) {
            Text("Example prompts")
                .font(AUCDesign.FontToken.sans(size: 18, weight: .medium))
                .foregroundStyle(AUCDesign.ColorToken.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AUCDesign.Space.md), count: 3),
                spacing: AUCDesign.Space.md
            ) {
                PromptCard(
                    title: "Summarize the newest PDF in Downloads",
                    subtitle: "Files"
                ) {
                    model.composer.prompt = "Open my Downloads folder and summarize the newest PDF."
                }
                PromptCard(
                    title: "Find an invoice and prepare a short note",
                    subtitle: "Search"
                ) {
                    model.composer.prompt = "Find the latest invoice in my documents and prepare a short summary."
                }
                PromptCard(
                    title: "Resume a previous task from history",
                    subtitle: "Context"
                ) {
                    model.isLauncherPresented = true
                }
            }
        }
    }
}

private struct StatusBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: AUCDesign.Space.sm) {
            Image(systemName: systemImage)
                .font(AUCDesign.FontToken.sans(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AUCDesign.FontToken.sans(size: 13, weight: .semibold))
                    .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                Text(message)
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(AUCDesign.Space.md)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                .stroke(color.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct ModelIndicator: View {
    @Bindable var model: AUCAppModel

    var body: some View {
        HStack(spacing: AUCDesign.Space.xs) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(AUCDesign.FontToken.sans(size: 12, weight: .semibold))
                .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AUCDesign.ColorToken.panel)
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        if model.providerSettings.hasReadyProvider { return AUCDesign.ColorToken.green }
        if model.executorPhase == .starting || model.executorPhase == .repairing { return AUCDesign.ColorToken.violetLight }
        return AUCDesign.ColorToken.amber
    }

    private var label: String {
        if model.providerSettings.hasReadyProvider {
            return model.providerSettings.selectedModel?.model ?? AUCAppModel.openAIDemoModelID
        }
        switch model.executorPhase {
        case .starting:
            return "Starting executor"
        case .repairing:
            return "Repairing executor"
        case .failed:
            return "Executor repair"
        case .crashed:
            return "Executor crashed"
        case .installBlocked:
            return "Install required"
        case .connected:
            return "Provider setup"
        }
    }
}

private struct PromptCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AUCDesign.Space.sm) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(AUCDesign.FontToken.sans(size: 14, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: AUCDesign.Space.xs)
                    Image(systemName: "arrow.up.left")
                        .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                        .foregroundStyle(AUCDesign.ColorToken.textSecondary)
                }

                Spacer(minLength: AUCDesign.Space.sm)

                Text(subtitle)
                    .font(AUCDesign.FontToken.sans(size: 12, weight: .medium))
                    .foregroundStyle(AUCDesign.ColorToken.textSecondary)
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AUCDesign.Space.md)
            .background(AUCDesign.ColorToken.card.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AUCDesign.Radius.lg, style: .continuous)
                    .stroke(AUCDesign.ColorToken.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SubmitCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(configuration.isPressed ? AUCDesign.ColorToken.violetDark : AUCDesign.ColorToken.violet)
            .foregroundStyle(.white)
            .clipShape(Circle())
            .shadow(color: AUCDesign.ColorToken.violet.opacity(0.28), radius: 9)
    }
}
