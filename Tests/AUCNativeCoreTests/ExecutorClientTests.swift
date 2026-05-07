import Testing
@testable import AUCNativeCore

struct ExecutorClientTests {
    @Test func startTaskSendsTypedJSONRPCRequest() async throws {
        let response = #"{"jsonrpc":"2.0","id":1,"result":{"id":"task-1","prompt":"Open Downloads","status":"running","createdAt":"2026-05-07T10:00:00Z"}}"#
        let transport = MemoryTransport(inboundLines: [response])
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        let task = try await client.startTask(AUCTaskComposerState(prompt: "Open Downloads"))

        #expect(task.id == "task-1")
        #expect(task.status == .running)
        let sentLine = await transport.sentLines.first ?? ""
        #expect(sentLine.contains("\"method\":\"task.start\""))
        #expect(sentLine.contains("\"prompt\":\"Open Downloads\""))
    }

    @Test func startTaskUsesCallerProvidedTaskID() async throws {
        let response = #"{"jsonrpc":"2.0","id":1,"result":{"id":"native-known-task","prompt":"hi","status":"running","createdAt":"2026-05-07T10:00:00Z"}}"#
        let transport = MemoryTransport(inboundLines: [response])
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        _ = try await client.startTask(AUCTaskComposerState(prompt: "hi", clientTaskID: "native-known-task"))

        let sentLine = await transport.sentLines.first ?? ""
        #expect(sentLine.contains("\"taskId\":\"native-known-task\""))
    }

    @Test func rpcErrorIsSurfaced() async throws {
        let response = #"{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"Provider missing"}}"#
        let transport = MemoryTransport(inboundLines: [response])
        let client = ExecutorClient(transport: transport)

        do {
            _ = try await client.getProviderSettings()
            Issue.record("Expected provider error")
        } catch let error as ExecutorClientError {
            #expect(error == .rpcError(code: -32000, message: "Provider missing"))
        }
    }

    @Test func saveOpenAIKeyWritesDaemonProviderState() async throws {
        let ok = #"{"jsonrpc":"2.0","id":ID,"result":null}"#
        let transport = MemoryTransport(inboundLines: (1...5).map { ok.replacingOccurrences(of: "ID", with: "\($0)") })
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        try await client.saveOpenAIAPIKey(
            apiKey: "sk-proj-abcdefghijklmnopqrstuvwxyz",
            baseURL: "https://api.openai.com/v1",
            modelID: "openai/gpt-5.2"
        )

        let sentLines = await transport.sentLines.joined(separator: "\n")
        #expect(sentLines.contains("\"method\":\"settings.setOpenAiBaseUrl\""))
        #expect(sentLines.contains("\"baseUrl\":\"https:\\/\\/api.openai.com\\/v1\""))
        #expect(sentLines.contains("\"method\":\"secrets.storeApiKey\""))
        #expect(sentLines.contains("\"provider\":\"openai\""))
        #expect(sentLines.contains("\"apiKey\":\"sk-proj-abcdefghijklmnopqrstuvwxyz\""))
        #expect(sentLines.contains("\"method\":\"provider.setConnected\""))
        #expect(sentLines.contains("\"selectedModelId\":\"openai\\/gpt-5.2\""))
        #expect(sentLines.contains("\"connectionStatus\":\"connected\""))
        #expect(sentLines.contains("\"method\":\"provider.setActive\""))
        #expect(sentLines.contains("\"method\":\"settings.setSelectedModel\""))
    }

    @Test func saveOpenAIKeySkipsDaemonNotifications() async throws {
        let notification = #"{"jsonrpc":"2.0","method":"settings.changed","params":{"key":"openaiBaseUrl","value":""}}"#
        let ok = #"{"jsonrpc":"2.0","id":ID,"result":null}"#
        let transport = MemoryTransport(inboundLines: [
            notification,
            ok.replacingOccurrences(of: "ID", with: "1"),
            notification,
            ok.replacingOccurrences(of: "ID", with: "2"),
            notification,
            ok.replacingOccurrences(of: "ID", with: "3"),
            ok.replacingOccurrences(of: "ID", with: "4"),
            ok.replacingOccurrences(of: "ID", with: "5")
        ])
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        try await client.saveOpenAIAPIKey(
            apiKey: "sk-proj-abcdefghijklmnopqrstuvwxyz",
            baseURL: "",
            modelID: "openai/gpt-5.2"
        )

        let sentLines = await transport.sentLines.joined(separator: "\n")
        #expect(sentLines.contains("\"method\":\"settings.setSelectedModel\""))
    }

    @Test func cancelTaskUsesDaemonCancelContract() async throws {
        let response = #"{"jsonrpc":"2.0","id":1,"result":null}"#
        let transport = MemoryTransport(inboundLines: [response])
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        try await client.cancelTask(id: "task-1")

        let sentLine = await transport.sentLines.first ?? ""
        #expect(sentLine.contains("\"method\":\"task.cancel\""))
        #expect(sentLine.contains("\"taskId\":\"task-1\""))
    }

    @Test func startTaskSkipsProgressNotificationBeforeResponse() async throws {
        let notification = #"{"jsonrpc":"2.0","method":"task.progress","params":{"taskId":"task-1","message":"Working"}}"#
        let response = #"{"jsonrpc":"2.0","id":1,"result":{"id":"task-1","prompt":"hi","status":"running","createdAt":"2026-05-07T10:00:00Z"}}"#
        let transport = MemoryTransport(inboundLines: [notification, response])
        let client = ExecutorClient(transport: transport)

        try await client.connect()
        let task = try await client.startTask(AUCTaskComposerState(prompt: "hi"))

        #expect(task.id == "task-1")
        #expect(task.status == .running)
    }

    @Test func callTimesOutWhenDaemonDoesNotAnswer() async throws {
        let transport = HangingTransport()
        let client = ExecutorClient(
            transport: transport,
            requestTimeout: .milliseconds(10),
            requestTimeoutSeconds: 0.01
        )

        try await client.connect()

        do {
            _ = try await client.getProviderSettings()
            Issue.record("Expected timeout")
        } catch let error as ExecutorClientError {
            #expect(error == .requestTimedOut(method: "provider.getSettings", seconds: 0.01))
        }
    }
}

private actor HangingTransport: ExecutorTransport {
    func connect() async throws {}
    func sendLine(_ line: String) async throws {}

    func readLine() async throws -> String {
        try await Task.sleep(for: .seconds(60))
        throw ExecutorTransportError.disconnected
    }

    func close() async {}
}
