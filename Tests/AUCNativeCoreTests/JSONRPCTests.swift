import Testing
@testable import AUCNativeCore

struct JSONRPCTests {
    @Test func requestEncodingIsLineDelimitedJSONRPC() throws {
        let line = try JSONRPCLineCodec.encode(
            JSONRPCRequest(id: 7, method: "task.cancel", params: .object(["taskId": .string("abc")]))
        )

        #expect(line.hasSuffix("\n"))
        #expect(line.contains("\"jsonrpc\":\"2.0\""))
        #expect(line.contains("\"method\":\"task.cancel\""))
    }

    @Test func responseDecodingMapsResult() throws {
        let response = try JSONRPCLineCodec.decodeResponse(#"{"jsonrpc":"2.0","id":1,"result":{"ok":true}}"#)

        #expect(response.id == 1)
        #expect(response.result == .object(["ok": .bool(true)]))
    }

    @Test func notificationDecodingMapsMethodAndParams() throws {
        let notification = try JSONRPCLineCodec.decodeNotification(
            #"{"jsonrpc":"2.0","method":"task.progress","params":{"taskId":"task-1","stage":"tool-use","message":"Opening browser"}}"#
        )

        #expect(notification.method == "task.progress")
        #expect(notification.params == .object([
            "taskId": .string("task-1"),
            "stage": .string("tool-use"),
            "message": .string("Opening browser")
        ]))
    }
}
