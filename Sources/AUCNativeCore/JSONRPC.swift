import Foundation

public struct JSONRPCRequest: Codable, Equatable, Sendable {
    public var jsonrpc = "2.0"
    public var id: Int
    public var method: String
    public var params: JSONValue?

    public init(id: Int, method: String, params: JSONValue? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCResponse: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var id: Int?
    public var result: JSONValue?
    public var error: JSONRPCError?
}

public struct JSONRPCNotification: Codable, Equatable, Sendable {
    public var jsonrpc: String?
    public var method: String
    public var params: JSONValue?
}

public struct JSONRPCError: Codable, Equatable, Error, Sendable {
    public var code: Int
    public var message: String
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum JSONRPCLineCodec {
    public static func encode(_ request: JSONRPCRequest) throws -> String {
        let data = try JSONEncoder().encode(request)
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    public static func decodeResponse(_ line: String) throws -> JSONRPCResponse {
        let data = Data(line.utf8)
        return try JSONDecoder().decode(JSONRPCResponse.self, from: data)
    }

    public static func decodeNotification(_ line: String) throws -> JSONRPCNotification {
        let data = Data(line.utf8)
        return try JSONDecoder().decode(JSONRPCNotification.self, from: data)
    }

    public static func decodeValue<T: Decodable>(_ value: JSONValue?, as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(value ?? .null)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
