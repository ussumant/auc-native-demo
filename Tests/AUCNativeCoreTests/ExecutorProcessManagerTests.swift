import Testing
@testable import AUCNativeCore

struct ExecutorProcessManagerTests {
    @Test func parsesProcessListRows() {
        let processes = ExecutorProcessManager.parseProcessList("""
          123 /Applications/AUC Native.app/Contents/Resources/nodejs/bin/node daemon/index.js --socket-path /tmp/daemon.sock
          456 /usr/bin/true
        """)

        #expect(processes == [
            AUCManagedRuntimeProcess(
                pid: 123,
                command: "/Applications/AUC Native.app/Contents/Resources/nodejs/bin/node daemon/index.js --socket-path /tmp/daemon.sock"
            ),
            AUCManagedRuntimeProcess(pid: 456, command: "/usr/bin/true")
        ])
    }

    @Test func detectsManagedDaemonForSocket() {
        let command = "/Applications/AUC Native.app/Contents/Resources/nodejs/bin/node /Applications/AUC Native.app/Contents/Resources/Executor/daemon/index.js --socket-path /Users/demo/daemon.sock"

        #expect(ExecutorProcessManager.isManagedDaemonProcess(command, socketPath: "/Users/demo/daemon.sock"))
        #expect(!ExecutorProcessManager.isManagedDaemonProcess(command, socketPath: "/tmp/other.sock"))
    }

    @Test func detectsStaleBundleProcess() {
        let command = "/Users/demo/dev/auc-native/dist/AUCNative.app/Contents/Resources/nodejs/bin/node /Users/demo/dev/auc-native/dist/AUCNative.app/Contents/Resources/Executor/daemon/index.js"

        #expect(ExecutorProcessManager.isStaleManagedProcess(
            command,
            expectedResourcesPath: "/Applications/AUC Native.app/Contents/Resources"
        ))
        #expect(!ExecutorProcessManager.isStaleManagedProcess(
            command,
            expectedResourcesPath: "/Users/demo/dev/auc-native/dist/AUCNative.app/Contents/Resources"
        ))
    }
}
