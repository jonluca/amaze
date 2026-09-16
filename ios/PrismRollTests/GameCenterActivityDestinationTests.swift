import XCTest
@testable import PrismRoll

final class GameCenterActivityDestinationTests: XCTestCase {
    func testOnlyTheThreeRegisteredActivityIDsOpenKnownDestinations() {
        let cases: [(String, GameCenterActivityDestination)] = [
            ("com.jonluca.prismroll.activity.classic", .classic),
            ("com.jonluca.prismroll.activity.time_rush", .timeRush),
            ("com.jonluca.prismroll.activity.daily", .daily)
        ]
        XCTAssertEqual(Set(GameCenterActivityDestination.allCases.map(\.id)), Set(cases.map(\.0)))
        for (identifier, destination) in cases {
            XCTAssertEqual(GameCenterActivityDestination(identifier: identifier), destination)
        }
    }

    func testUnknownOrAlteredActivityIDsNeverFallBackToGameplay() {
        let rejected = [
            "", "classic", "time_rush", "daily", "com.jonluca.prismroll.activity.duel",
            "com.jonluca.prismroll.activity.Classic", "com.jonluca.prismroll.activity.classic ",
            " com.jonluca.prismroll.activity.daily", "com.jonluca.prismroll.activity.classic.extra",
            "com.jonluca.prismroll.leaderboard.classic_completed", "com.other.game.activity.daily"
        ]
        for identifier in rejected {
            XCTAssertNil(GameCenterActivityDestination(identifier: identifier), identifier)
        }
    }
}
