import Foundation
import Testing
@testable import AUCNativeCore

struct ComposerStateTests {
    @Test func promptOnlyComposerCanSubmit() {
        let state = AUCTaskComposerState(prompt: "  open downloads  ")

        #expect(state.trimmedPrompt == "open downloads")
        #expect(state.canSubmit)
    }

    @Test func emptyComposerCannotSubmitWithoutAttachments() {
        #expect(!AUCTaskComposerState(prompt: "   ").canSubmit)
    }

    @Test func attachmentOnlyComposerCanSubmit() {
        let attachment = AUCFileAttachment(url: URL(fileURLWithPath: "/tmp/report.pdf"))
        let state = AUCTaskComposerState(attachments: [attachment])

        #expect(state.canSubmit)
        #expect(state.attachments.first?.displayName == "report.pdf")
    }

    @Test func followUpModeStoresTaskID() {
        let state = AUCTaskComposerState(prompt: "send it", mode: .followUp(taskID: "task-123"))

        #expect(state.mode == .followUp(taskID: "task-123"))
    }
}
