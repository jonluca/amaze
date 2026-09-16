import Foundation

struct DiagnosticsRuntime {
    let allowsCollection: Bool

    init(arguments: [String], environment: [String: String], isDebugBuild: Bool, isRunningTests: Bool = false) {
        let isTestRun = isRunningTests
            || arguments.contains("--uitesting")
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
        allowsCollection = !isTestRun && (!isDebugBuild || arguments.contains("--diagnostics-debug"))
    }

    static var current: DiagnosticsRuntime {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        return DiagnosticsRuntime(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            isDebugBuild: isDebugBuild,
            isRunningTests: NSClassFromString("XCTestCase") != nil
        )
    }
}
