import XCTest

final class AdmitPathUITests: XCTestCase {
    func testDefaultLaunchShowsSignInGate() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.buttons["Continue with Google"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sign in to open your admissions workspace"].exists)
    }

    func testGuestLaunchShowsOnboardingWelcome() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathGuestMode"]
        app.launch()

        XCTAssertTrue(app.buttons["Start guided setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Load sample demo"].exists)
    }

    func testGuestSampleLaunchShowsRoadmapTabs() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathGuestMode", "-AdmitPathLoadSampleData"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Community"].exists)
        XCTAssertTrue(app.tabBars.buttons["Apply"].exists)
        XCTAssertTrue(app.tabBars.buttons["Funding"].exists)
    }

    func testGuestSampleLaunchCanOpenProgramFundingFlowFromToday() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathGuestMode", "-AdmitPathLoadSampleData"]
        app.launch()

        let topMatchButton = app.buttons["today-top-match-0"].firstMatch
        XCTAssertTrue(topMatchButton.waitForExistence(timeout: 5))
        topMatchButton.tap()

        XCTAssertTrue(app.staticTexts["Decision summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open funding planning"].waitForExistence(timeout: 5))
        app.buttons["Open funding planning"].tap()

        XCTAssertTrue(app.staticTexts["Family funding plan"].waitForExistence(timeout: 5))
    }

    func testGuestSampleLaunchCanOpenApplicationWorkspaceFromApply() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathGuestMode", "-AdmitPathLoadSampleData"]
        app.launch()

        app.tabBars.buttons["Apply"].tap()

        let applicationButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "MSc Business Analytics")).firstMatch
        XCTAssertTrue(applicationButton.waitForExistence(timeout: 5))
        applicationButton.tap()

        XCTAssertTrue(app.staticTexts["Progress summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open essay workspace"].exists)
    }

    func testMockAuthenticatedLaunchShowsSignedInAccountControls() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathMockAuthenticated", "-AdmitPathLoadSampleData"]
        app.launch()

        openAccount(in: app)

        XCTAssertTrue(app.buttons["Sign out of Google"].waitForExistence(timeout: 5))
    }

    func testAdminPreviewLaunchShowsStaffTools() {
        let app = makeApp()
        app.launchArguments = ["-AdmitPathAdminPreview", "-AdmitPathLoadSampleData"]
        app.launch()

        openAccount(in: app)

        XCTAssertTrue(app.staticTexts["Staff tools"].waitForExistence(timeout: 5))
    }

    private func openAccount(in app: XCUIApplication) {
        let accountButton = app.buttons["Open account"].firstMatch
        XCTAssertTrue(accountButton.waitForExistence(timeout: 5))
        accountButton.tap()
    }

    private func makeApp(testName: String = #function) -> XCUIApplication {
        let app = XCUIApplication()
        let sanitizedName = testName
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let baseDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("AdmitPathUITests", isDirectory: true)
            .appendingPathComponent("\(sanitizedName)-\(UUID().uuidString)", isDirectory: true)
        app.launchEnvironment["ADMITPATH_BASE_DIRECTORY"] = baseDirectory.path
        return app
    }
}
