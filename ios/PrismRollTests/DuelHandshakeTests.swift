#if canImport(UIKit) || DUEL_STANDALONE_TESTS
import Foundation
import XCTest
@testable import PrismRoll

final class DuelHandshakeTests: XCTestCase {
    func testLegacyPeerCannotStartADifferentGeneratedMaze() throws {
        let oldHello = Data(#"{"hello":{"version":1}}"#.utf8)
        let message = try JSONDecoder().decode(DuelMessage.self, from: oldHello)
        var handshake = DuelHandshake()
        XCTAssertFalse(handshake.accepts(message))
        XCTAssertFalse(handshake.isCompatible)
        XCTAssertFalse(handshake.accepts(.setup(id: "match", seed: 5)))
        XCTAssertFalse(handshake.accepts(.start(id: "match")))
        XCTAssertFalse(handshake.accepts(.hello(version: DuelHandshake.version)),
                       "A rejected connection cannot be revived by a later packet")
    }

    func testSetupAndStartRequireAPriorCompatibleHelloIncludingInvites() {
        for message in [DuelMessage.setup(id: "match", seed: 5), .ready(id: "match"), .start(id: "match")] {
            var handshake = DuelHandshake()
            XCTAssertFalse(handshake.isCompatible)
            XCTAssertFalse(handshake.accepts(message))
            XCTAssertFalse(handshake.isCompatible)
        }
    }

    func testCompatiblePeersCanExchangeTheWholeRoundProtocol() throws {
        var handshake = DuelHandshake()
        let messages: [DuelMessage] = [
            .hello(version: DuelHandshake.version), .hello(version: DuelHandshake.version),
            .setup(id: "match", seed: 5),
            .ready(id: "match"), .start(id: "match"),
            .progress(id: "match", painted: 10, total: 10, moves: 12),
            .finish(id: "match"), .result(id: "match", winner: "peer")
        ]
        for message in messages {
            let data = try JSONEncoder().encode(message)
            XCTAssertTrue(handshake.accepts(try JSONDecoder().decode(DuelMessage.self, from: data)))
        }
        XCTAssertTrue(handshake.isCompatible)
    }

    func testNewMatchCannotInheritPreviousCompatibility() {
        var handshake = DuelHandshake()
        XCTAssertTrue(handshake.accepts(.hello(version: DuelHandshake.version)))
        handshake = DuelHandshake()
        XCTAssertFalse(handshake.isCompatible)
        XCTAssertFalse(handshake.accepts(.progress(id: "old", painted: 1, total: 10, moves: 0)))
        handshake = DuelHandshake()
        XCTAssertTrue(handshake.accepts(.hello(version: DuelHandshake.version)))
        XCTAssertFalse(handshake.accepts(.hello(version: DuelHandshake.version + 1)))
        XCTAssertFalse(handshake.accepts(.finish(id: "match")))
    }
}
#endif
