//
//  ScrollappUITests.swift
//  ScrollappUITests
//

import XCTest

final class ScrollappUITests: XCTestCase {
    private let launchTimeout: TimeInterval = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesInUITestMode() throws {
        let app = configuredApplication()
        app.launch()

        XCTAssertTrue(
            waitForRunningState(app),
            "Expected Scrollapp to reach a running state in UI test mode."
        )
    }

    @MainActor
    private func configuredApplication() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.fromis9.scrollapp")
        app.launchArguments.append("--scrollapp-test-mode")
        app.launchEnvironment["SCROLLAPP_TEST_MODE"] = "ui-testing"
        app.launchEnvironment["SCROLLAPP_UI_TEST_MODE"] = "1"
        return app
    }

    @MainActor
    private func waitForRunningState(_ app: XCUIApplication) -> Bool {
        wait(
            until: { state in
                state == .runningForeground ||
                state == .runningBackground
            },
            for: app,
            timeout: launchTimeout
        )
    }

    @MainActor
    private func wait(
        until predicate: (XCUIApplication.State) -> Bool,
        for app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(app.state) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return predicate(app.state)
    }
}
