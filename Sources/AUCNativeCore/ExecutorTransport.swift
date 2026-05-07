import Darwin
import Foundation

public protocol ExecutorTransport: Sendable {
    func connect() async throws
    func sendLine(_ line: String) async throws
    func readLine() async throws -> String
    func close() async
}

public enum ExecutorTransportError: LocalizedError, Equatable {
    case socketPathTooLong
    case socketCreateFailed(errno: Int32)
    case connectFailed(errno: Int32)
    case writeFailed(errno: Int32)
    case readFailed(errno: Int32)
    case disconnected

    public var errorDescription: String? {
        switch self {
        case .socketPathTooLong:
            return "The daemon socket path is too long for a Unix domain socket."
        case .socketCreateFailed(let code):
            return "Could not create daemon socket: errno \(code)."
        case .connectFailed(let code):
            return "Could not connect to daemon socket: errno \(code)."
        case .writeFailed(let code):
            return "Could not write to daemon socket: errno \(code)."
        case .readFailed(let code):
            return "Could not read from daemon socket: errno \(code)."
        case .disconnected:
            return "The daemon socket disconnected."
        }
    }
}

public final class UnixSocketTransport: ExecutorTransport, @unchecked Sendable {
    private let socketPath: String
    private let fdLock = NSLock()
    private var fd: Int32 = -1
    private var readBuffer = Data()
    private var newlineSearchStart = 0

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    public func connect() async throws {
        try connectSync()
    }

    private func connectSync() throws {
        fdLock.lock()
        defer { fdLock.unlock() }
        if fd >= 0 { return }
        let newFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard newFD >= 0 else {
            throw ExecutorTransportError.socketCreateFailed(errno: errno)
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard socketPath.utf8.count < maxPathLength else {
            Darwin.close(newFD)
            throw ExecutorTransportError.socketPathTooLong
        }

        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { charPointer in
                socketPath.withCString { source in
                    strncpy(charPointer, source, maxPathLength)
                }
            }
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(newFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            let code = errno
            Darwin.close(newFD)
            throw ExecutorTransportError.connectFailed(errno: code)
        }

        fd = newFD
    }

    public func sendLine(_ line: String) async throws {
        let currentFD = try activeFileDescriptor()
        let bytes = Array(line.utf8)
        var sent = 0
        while sent < bytes.count {
            let count = bytes.withUnsafeBytes { rawBuffer in
                Darwin.write(currentFD, rawBuffer.baseAddress!.advanced(by: sent), bytes.count - sent)
            }
            guard count > 0 else {
                throw ExecutorTransportError.writeFailed(errno: errno)
            }
            sent += count
        }
    }

    public func readLine() async throws -> String {
        let currentFD = try activeFileDescriptor()
        while true {
            let searchStart = min(newlineSearchStart, readBuffer.count)
            if let newlineIndex = readBuffer[searchStart...].firstIndex(of: 10) {
                let lineData = readBuffer.prefix(upTo: newlineIndex)
                readBuffer.removeSubrange(...newlineIndex)
                newlineSearchStart = 0
                return String(decoding: lineData, as: UTF8.self)
            }
            newlineSearchStart = readBuffer.count

            var chunk = [UInt8](repeating: 0, count: 16 * 1024)
            let count = chunk.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(currentFD, rawBuffer.baseAddress!, rawBuffer.count)
            }
            if count > 0 {
                readBuffer.append(contentsOf: chunk.prefix(count))
            } else if count == 0 {
                throw ExecutorTransportError.disconnected
            } else {
                throw ExecutorTransportError.readFailed(errno: errno)
            }
        }
    }

    public func close() async {
        closeSync()
    }

    private func closeSync() {
        fdLock.lock()
        defer { fdLock.unlock() }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
        readBuffer.removeAll()
        newlineSearchStart = 0
    }

    private func activeFileDescriptor() throws -> Int32 {
        fdLock.lock()
        defer { fdLock.unlock() }
        guard fd >= 0 else { throw ExecutorTransportError.disconnected }
        return fd
    }
}

public actor MemoryTransport: ExecutorTransport {
    public private(set) var sentLines: [String] = []
    private var inboundLines: [String]

    public init(inboundLines: [String] = []) {
        self.inboundLines = inboundLines
    }

    public func enqueue(_ line: String) {
        inboundLines.append(line)
    }

    public func connect() async throws {}

    public func sendLine(_ line: String) async throws {
        sentLines.append(line)
    }

    public func readLine() async throws -> String {
        guard !inboundLines.isEmpty else { throw ExecutorTransportError.disconnected }
        return inboundLines.removeFirst()
    }

    public func close() async {}
}
