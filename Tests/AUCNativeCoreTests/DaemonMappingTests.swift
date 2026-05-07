import Foundation
import Testing
@testable import AUCNativeCore

struct DaemonMappingTests {
    @Test func daemonTaskMapsToNativeRecord() {
        let dto = DaemonTaskDTO(
            id: "task-1",
            prompt: "Open Downloads",
            description: nil,
            summary: "Opened Downloads",
            status: "completed",
            createdAt: "2026-05-07T10:00:00Z",
            updatedAt: nil,
            completedAt: "2026-05-07T10:02:00Z",
            artifactPaths: ["/tmp/proof.txt"],
            artifacts: nil
        )

        let record = AUCTaskRecord(daemon: dto)

        #expect(record.id == "task-1")
        #expect(record.status == .completed)
        #expect(record.artifactURLs.first?.path == "/tmp/proof.txt")
    }

    @Test func providerReadinessRequiresConnectedProviderWithModel() {
        let dto = DaemonProviderSettingsDTO(
            selectedModel: .init(provider: "openai", model: "gpt-5.2", id: nil),
            connectedProviders: [
                "openai": .init(connectionStatus: "connected", selectedModelId: "gpt-5.2")
            ]
        )

        let settings = AUCProviderSettings(daemon: dto)

        #expect(settings.hasReadyProvider)
        #expect(settings.selectedModel == AUCModelSelection(provider: "openai", model: "gpt-5.2"))
    }
}
