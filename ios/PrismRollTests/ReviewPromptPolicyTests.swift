import XCTest
@testable import PrismRoll

final class ReviewPromptPolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    func testNeedsTenCompletionsAndThreeSeparateEngagementDays() {
        var policy = ReviewPromptPolicy()
        policy.recordEngagement(at: start)
        policy.recordEngagement(at: start)
        XCTAssertEqual(policy.engagedDays, 1)
        XCTAssertFalse(policy.isEligible(completedLevels: 100, at: day(1)))
        policy.recordEngagement(at: day(1))
        policy.recordEngagement(at: day(2))
        XCTAssertFalse(policy.isEligible(completedLevels: 9, at: day(2)))
        XCTAssertTrue(policy.isEligible(completedLevels: 10, at: day(2)))
    }

    func testRequestPersistsThroughEncodingAndRequiresCooldownAndNewProgress() throws {
        var policy = engagedPolicy()
        XCTAssertTrue(policy.recordRequest(completedLevels: 10, at: day(2)))
        var restored = try JSONDecoder().decode(ReviewPromptPolicy.self, from: JSONEncoder().encode(policy))
        XCTAssertFalse(restored.recordRequest(completedLevels: 100, at: day(3)))
        XCTAssertFalse(restored.recordRequest(completedLevels: 19, at: day(122)))
        XCTAssertTrue(restored.recordRequest(completedLevels: 20, at: day(122)))
        XCTAssertFalse(restored.isEligible(completedLevels: 100, at: start))
    }

    func testCapsRequestsAtThreeInRollingYear() {
        var policy = engagedPolicy()
        XCTAssertTrue(policy.recordRequest(completedLevels: 10, at: day(2)))
        XCTAssertTrue(policy.recordRequest(completedLevels: 20, at: day(122)))
        XCTAssertTrue(policy.recordRequest(completedLevels: 30, at: day(242)))
        XCTAssertFalse(policy.recordRequest(completedLevels: 40, at: day(362)))
        XCTAssertTrue(policy.recordRequest(completedLevels: 40, at: day(367)))
        XCTAssertEqual(policy.requestedAt.count, 3)
    }

    func testClockMovingBackwardsDoesNotManufactureEngagementDays() {
        var policy = engagedPolicy()
        policy.recordEngagement(at: start)
        policy.recordEngagement(at: day(1))
        XCTAssertEqual(policy.engagedDays, 3)
    }

    private func day(_ offset: Int) -> Date { start.addingTimeInterval(Double(offset) * 86_400) }

    private func engagedPolicy() -> ReviewPromptPolicy {
        var policy = ReviewPromptPolicy()
        for offset in 0..<3 { policy.recordEngagement(at: day(offset)) }
        return policy
    }
}
