import Foundation

enum GameCenterRuntime {
    case live
    case suppressed
    case authenticatedFixture

    static var current: GameCenterRuntime {
        let process = ProcessInfo.processInfo
        #if DEBUG
        if process.environment["PRISM_GAME_CENTER_STATE"] == "authenticated" { return .authenticatedFixture }
        if process.environment["PRISM_GAME_CENTER_STATE"] == "offline" { return .suppressed }
        if process.arguments.contains("--no-ads") { return .suppressed }
        #endif
        if process.arguments.contains("--uitesting")
            || process.environment["XCTestConfigurationFilePath"] != nil
            || process.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil { return .suppressed }
        return .live
    }
}
