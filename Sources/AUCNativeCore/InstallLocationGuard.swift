import Foundation

public struct AUCInstallLocationStatus: Equatable, Sendable {
    public var isBlocked: Bool
    public var isRunningFromDMG: Bool
    public var isTranslocated: Bool
    public var appPath: String
    public var message: String

    public init(
        isBlocked: Bool,
        isRunningFromDMG: Bool,
        isTranslocated: Bool,
        appPath: String,
        message: String
    ) {
        self.isBlocked = isBlocked
        self.isRunningFromDMG = isRunningFromDMG
        self.isTranslocated = isTranslocated
        self.appPath = appPath
        self.message = message
    }
}

public enum AUCInstallLocationGuard {
    public static let overrideEnvironmentKey = "AUC_ALLOW_UNINSTALLED_DEMO_LAUNCH"

    public static func evaluate(
        appPath: String,
        isOpenAIDemoMode: Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AUCInstallLocationStatus {
        let isRunningFromDMG = appPath.hasPrefix("/Volumes/")
        let isTranslocated = appPath.contains("/AppTranslocation/")
        let overrideEnabled = environment[overrideEnvironmentKey] == "1"
        let isBlocked = isOpenAIDemoMode && !overrideEnabled && (isRunningFromDMG || isTranslocated)
        let message: String
        if isBlocked {
            message = "Move AUC Native to Applications before starting the executor."
        } else if overrideEnabled {
            message = "Install guard bypassed for development."
        } else {
            message = "Install location is ready."
        }
        return AUCInstallLocationStatus(
            isBlocked: isBlocked,
            isRunningFromDMG: isRunningFromDMG,
            isTranslocated: isTranslocated,
            appPath: appPath,
            message: message
        )
    }
}
