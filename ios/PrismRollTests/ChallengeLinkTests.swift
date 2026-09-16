import XCTest
@testable import PrismRoll

final class ChallengeLinkTests: XCTestCase {
    func testRoundTripPreservesActualBoardsAndScoresWithoutImportingRewards() throws {
        for number in [1, 8, 30, 100] {
            let original = MazeLevel.generate(number: number, mode: .endless)
            let challenge = try ChallengeLink.make(level: original, title: "Classic · Level \(number)", moves: original.solution.count)
            let decoded = try ChallengeLink.decode(challenge.url)
            XCTAssertTrue(decoded.level.hasSameGrid(as: original))
            XCTAssertEqual(decoded.senderMoves, original.solution.count)
            XCTAssertEqual(decoded.level.solution, original.solution)
            XCTAssertEqual(decoded.url, challenge.url)
            XCTAssertNil(decoded.level.moveLimit)
            XCTAssertNil(decoded.level.timeLimit)
            XCTAssertTrue(decoded.level.coinCells.isEmpty)
            var run = MazeRun(level: decoded.level)
            for direction in decoded.level.solution { run.move(direction, recomputeFallbackHint: false) }
            XCTAssertTrue(run.isComplete)
        }
    }

    func testDailyBoardCanBeSharedAndReplayedWithoutItsMoveBudget() throws {
        let daily = DailyChallenge.generate(for: Date(timeIntervalSince1970: 1_789_603_200))
        let decoded = try ChallengeLink.decode(ChallengeLink.make(level: daily.level, title: "Daily maze").url)
        XCTAssertTrue(decoded.level.hasSameGrid(as: daily.level))
        XCTAssertNil(decoded.senderMoves)
        XCTAssertNil(decoded.level.moveLimit)
    }

    func testCustomSchemeUsesIdenticalPayloadAndCanonicalizesToHTTPS() throws {
        let original = try sampleChallenge()
        let appURL = try XCTUnwrap(URL(string: original.url.absoluteString.replacingOccurrences(
            of: ChallengeLink.website, with: "prismroll://challenge")))
        XCTAssertEqual(try ChallengeLink.decode(appURL), original)
    }

    func testRejectsUnknownOriginsDuplicateParametersAndFutureVersions() throws {
        let original = try sampleChallenge().url.absoluteString
        for invalid in [
            original.replacingOccurrences(of: "https:", with: "http:"),
            original.replacingOccurrences(of: "thoughtahead.com", with: "thoughtahead.com.evil.test"),
            original.replacingOccurrences(of: "thoughtahead.com", with: "someone@thoughtahead.com"),
            original.replacingOccurrences(of: "?v=1", with: "?v=2"),
            original + "&v=1", original + "&p=duplicate", original + "#hidden",
            original.replacingOccurrences(of: "/challenge/", with: "/challenge/other/")
        ] {
            XCTAssertThrowsError(try ChallengeLink.decode(try XCTUnwrap(URL(string: invalid))), invalid)
        }
    }

    func testRejectsOversizedMalformedAndUnsolvablePayloads() throws {
        let valid: [String: Any] = ["w": 2, "h": 2, "s": 0, "o": "1111", "t": "A maze", "r": "RDL", "m": 3]
        XCTAssertNoThrow(try ChallengeLink.decode(payloadURL(valid)))
        let changes: [[String: Any]] = [
            ["w": 17], ["h": Int.max], ["s": 4], ["s": -1], ["o": "2111"], ["o": "0111"],
            ["o": "1001"], ["o": "1"], ["r": "R"], ["r": "URDL"], ["r": "XYZ"],
            ["r": String(repeating: "RDLU", count: 513)], ["t": ""], ["t": "Hidden\nTitle"],
            ["t": String(repeating: "a", count: 81)], ["m": 0], ["m": 100_001]
        ]
        for change in changes {
            let invalid = valid.merging(change) { _, new in new }
            XCTAssertThrowsError(try ChallengeLink.decode(payloadURL(invalid)), "\(change.keys)")
        }
        let oversized = URL(string: ChallengeLink.website + "?v=1&p=" + String(repeating: "A", count: 8_192))!
        XCTAssertThrowsError(try ChallengeLink.decode(oversized))
        XCTAssertThrowsError(try ChallengeLink.decode(URL(string: ChallengeLink.website + "?v=1&p=not-json")!))
    }

    func testGeometryAndSolutionAreIndependentOfCurrentNumberedGenerator() throws {
        let encoded = try payloadURL(["w": 2, "h": 2, "s": 0, "o": "1111", "t": "Archived board", "r": "RDL"])
        let decoded = try ChallengeLink.decode(encoded)
        XCTAssertEqual(decoded.level.width, 2)
        XCTAssertEqual(decoded.level.openCells.count, 4)
        XCTAssertNotEqual(decoded.level, MazeLevel.generate(number: 1, mode: .endless))
        XCTAssertEqual(decoded.level.solution, [.right, .down, .left])
    }

    private func sampleChallenge() throws -> SharedChallenge {
        try ChallengeLink.make(level: .generate(number: 1, mode: .endless), title: "Classic · Level 1", moves: 8)
    }

    private func payloadURL(_ payload: [String: Any]) throws -> URL {
        let encoded = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return try XCTUnwrap(URL(string: ChallengeLink.website + "?v=1&p=" + encoded))
    }
}
