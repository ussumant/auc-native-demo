import Foundation
import Testing
@testable import AUCNativeCore

struct DaemonEventSourceTests {
    @Test func mapsProgressAndPermissionNotifications() async throws {
        let transport = MemoryTransport(inboundLines: [
            #"{"jsonrpc":"2.0","method":"task.progress","params":{"taskId":"task-1","stage":"tool-use","message":"Opening browser"}}"#,
            #"{"jsonrpc":"2.0","method":"permission.request","params":{"id":"req-1","taskId":"task-1","type":"file","fileOperation":"modify","filePath":"/tmp/a.txt","createdAt":"2026-05-07T10:00:00Z"}}"#
        ])
        let source = DaemonEventSource(transport: transport)

        try await source.connect()
        let stream = await source.events()
        var iterator = stream.makeAsyncIterator()
        let progress = await iterator.next()
        let permission = await iterator.next()

        #expect(progress?.taskID == "task-1")
        #expect(progress?.type == "task.progress")
        #expect(progress?.message == "Opening browser")
        #expect(permission?.permissionRequest?.id == "req-1")
        #expect(permission?.status == .waitingPermission)
    }

    @Test func mapsMessageTodoAndBrowserFrameNotifications() async throws {
        let transport = MemoryTransport(inboundLines: [
            #"{"jsonrpc":"2.0","method":"task.message","params":{"taskId":"task-1","messages":[{"id":"msg-1","type":"tool","content":"clicked","toolName":"browser.click","toolStatus":"completed","timestamp":"2026-05-07T10:00:00Z"}]}}"#,
            #"{"jsonrpc":"2.0","method":"todo.update","params":{"taskId":"task-1","todos":[{"id":"todo-1","content":"Open settings","status":"completed","priority":"high"}]}}"#,
            #"{"jsonrpc":"2.0","method":"browser.frame","params":{"taskId":"task-1","title":"Example","url":"https://example.com","summary":"Frame received"}}"#
        ])
        let source = DaemonEventSource(transport: transport)

        try await source.connect()
        let stream = await source.events()
        var iterator = stream.makeAsyncIterator()
        let message = await iterator.next()
        let todo = await iterator.next()
        let frame = await iterator.next()

        #expect(message?.taskMessages.first?.toolName == "browser.click")
        #expect(todo?.todos.first?.content == "Open settings")
        #expect(frame?.browserFrame?.url == "https://example.com")
    }

    @Test func mapsRunningQuestionToolMessageToPermissionRequest() async throws {
        let transport = MemoryTransport(inboundLines: [
            #"{"jsonrpc":"2.0","method":"task.message","params":{"taskId":"task-1","messages":[{"id":"msg-question","type":"tool","content":"Tool question running","toolName":"question","toolStatus":"running","toolInput":{"questions":[{"question":"Where should I look?","header":"Data source","options":[{"label":"PDF statement","description":"Bank PDF"},{"label":"CSV file","description":"Local CSV"}],"multiple":false},{"question":"Where should I save it?","header":"Output"}]},"timestamp":"2026-05-07T10:00:00Z"}]}}"#
        ])
        let source = DaemonEventSource(transport: transport)

        try await source.connect()
        let stream = await source.events()
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()

        #expect(event?.status == .waitingPermission)
        #expect(event?.permissionRequest?.type == "question")
        #expect(event?.permissionRequest?.title == "Data source")
        #expect(event?.permissionRequest?.message.contains("Where should I save it?") == true)
        #expect(event?.permissionRequest?.options == ["PDF statement", "CSV file"])
    }

    @Test func detectsRunningBashWriteToDownloads() {
        let task = AUCTaskRecord(
            id: "task-1",
            prompt: "save csv",
            status: .running,
            createdAt: Date(),
            messages: [
                AUCTaskMessage(
                    id: "msg-bash",
                    type: "tool",
                    content: "Tool bash running",
                    toolName: "bash",
                    toolStatus: "running",
                    toolInputDescription: #"{"command":"cat > \"$HOME/Downloads/openai_transactions.csv\" << 'EOF'\nDate,Amount\nEOF"}"#,
                    timestamp: Date()
                )
            ]
        )

        #expect(task.runningFileWriteOperation?.url.path.hasSuffix("/Downloads/openai_transactions.csv") == true)
    }
}
