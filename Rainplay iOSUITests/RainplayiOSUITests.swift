import XCTest

// UI smoke tests (the Cypress-equivalent): drive the real app on a simulator and
// assert the critical flows work. Kept small and resilient — they check the
// always-present chrome (segmented controls, attribution, settings), never the
// network-dependent weather data, so they don't flake on CI without a network.
final class RainplayiOSUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // Skip the CoreLocation permission prompt (see AppModel.start()).
        app.launchArguments = ["-uiTestingSkipLocation"]
        app.launch()
        return app
    }

    @MainActor
    func testMainScreenRenders() {
        let app = launchApp()
        XCTAssertTrue(
            app.staticTexts["Weather data by Open-Meteo"].waitForExistence(timeout: 10),
            "Main screen did not render"
        )
        XCTAssertTrue(app.buttons["Vandaag"].exists)
        XCTAssertTrue(app.buttons["Week"].exists)
    }

    @MainActor
    func testDaySelectionUpdatesHero() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Weather data by Open-Meteo"].waitForExistence(timeout: 10))
        app.buttons["Morgen"].tap()
        XCTAssertTrue(app.staticTexts["Morgen"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testHorizonSelectionOnToday() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Weather data by Open-Meteo"].waitForExistence(timeout: 10))
        let plus2 = app.buttons["+2 uur"]
        XCTAssertTrue(plus2.waitForExistence(timeout: 3))
        plus2.tap()
        XCTAssertTrue(plus2.isSelected, "Tapped horizon segment should be selected")
    }

    @MainActor
    func testSettingsOpensAndCloses() {
        let app = launchApp()
        app.buttons["Instellingen"].tap()
        let title = app.navigationBars["Grafiekkleuren"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "Settings sheet did not open")
        app.buttons["Klaar"].tap()
        XCTAssertFalse(title.waitForExistence(timeout: 2), "Settings sheet did not dismiss")
    }
}
