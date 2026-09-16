import XCTest

final class DiagnosticsSettingsUITests: XCTestCase {
    @MainActor
    func testCrashSharingIsIndependentAndPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        openPrivacySettings(app)
        let diagnostics = app.switches["diagnosticsToggle"]
        let analytics = app.switches["analyticsToggle"]
        reveal(analytics, in: app, scrollingUp: true)
        set(analytics, enabled: false)
        reveal(diagnostics, in: app, scrollingUp: false)
        set(diagnostics, enabled: false)
        set(diagnostics, enabled: true)
        reveal(analytics, in: app, scrollingUp: true)
        XCTAssertEqual(analytics.value as? String, "0")
        app.terminate()

        // Resetting game progress must leave both independent consent choices intact.
        app.launch()
        openPrivacySettings(app)
        XCTAssertEqual(diagnostics.value as? String, "1")
        reveal(analytics, in: app, scrollingUp: true)
        XCTAssertEqual(analytics.value as? String, "0")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Independent crash-report consent"
        attachment.lifetime = .keepAlways
        add(attachment)
        reveal(diagnostics, in: app, scrollingUp: false)
        set(diagnostics, enabled: false)
        app.terminate()

        app.launch()
        openPrivacySettings(app)
        XCTAssertEqual(diagnostics.value as? String, "0")
        reveal(analytics, in: app, scrollingUp: true)
        XCTAssertEqual(analytics.value as? String, "0")
    }

    @MainActor
    private func openPrivacySettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 20))
        app.buttons["Settings"].tap()
        let toggle = app.switches["diagnosticsToggle"]
        for _ in 0..<10 where !toggle.exists || !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.exists && toggle.isHittable)
    }

    @MainActor
    private func reveal(_ toggle: XCUIElement, in app: XCUIApplication, scrollingUp: Bool) {
        for _ in 0..<8 where !toggle.exists || !toggle.isHittable {
            if scrollingUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(toggle.exists && toggle.isHittable)
    }

    @MainActor
    private func set(_ toggle: XCUIElement, enabled: Bool) {
        if (toggle.value as? String == "1") != enabled {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, enabled ? "1" : "0")
    }
}
