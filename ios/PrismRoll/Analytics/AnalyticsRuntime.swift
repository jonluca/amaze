import Foundation

struct AnalyticsRuntime {
    let allowsCollection: Bool

    init(
        arguments: [String],
        environment: [String: String],
        isDebugBuild: Bool,
        isRunningTests: Bool = false
    ) {
        let isTestRun = isRunningTests
            || arguments.contains("--uitesting")
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
        allowsCollection = !isTestRun && (!isDebugBuild || arguments.contains("--analytics-debug"))
    }

    static var current: AnalyticsRuntime {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        return AnalyticsRuntime(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            isDebugBuild: isDebugBuild,
            isRunningTests: NSClassFromString("XCTestCase") != nil
        )
    }
}
