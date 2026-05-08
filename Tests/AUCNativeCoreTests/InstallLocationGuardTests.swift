import Testing
@testable import AUCNativeCore

struct InstallLocationGuardTests {
    @Test func applicationsPathIsAllowedForOpenAIDemo() {
        let status = AUCInstallLocationGuard.evaluate(
            appPath: "/Applications/AUC Native.app",
            isOpenAIDemoMode: true,
            environment: [:]
        )

        #expect(!status.isBlocked)
        #expect(!status.isRunningFromDMG)
        #expect(!status.isTranslocated)
    }

    @Test func mountedDMGPathIsBlockedForOpenAIDemo() {
        let status = AUCInstallLocationGuard.evaluate(
            appPath: "/Volumes/AUC Native 0.1.1-openai-demo/AUC Native.app",
            isOpenAIDemoMode: true,
            environment: [:]
        )

        #expect(status.isBlocked)
        #expect(status.isRunningFromDMG)
    }

    @Test func translocatedPathIsBlockedForOpenAIDemo() {
        let status = AUCInstallLocationGuard.evaluate(
            appPath: "/private/var/folders/demo/AppTranslocation/ABC/d/AUC Native.app",
            isOpenAIDemoMode: true,
            environment: [:]
        )

        #expect(status.isBlocked)
        #expect(status.isTranslocated)
    }

    @Test func developmentOverrideAllowsUninstalledDemoLaunch() {
        let status = AUCInstallLocationGuard.evaluate(
            appPath: "/Volumes/AUC Native/AUC Native.app",
            isOpenAIDemoMode: true,
            environment: [AUCInstallLocationGuard.overrideEnvironmentKey: "1"]
        )

        #expect(!status.isBlocked)
        #expect(status.isRunningFromDMG)
    }
}
