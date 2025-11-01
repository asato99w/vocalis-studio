//
//  UITestHelpers.swift
//  VocalisStudioUITests
//
//  Common helpers for UI tests
//

import XCTest

extension XCTestCase {
    /// Launch app with recording count reset for UI tests
    func launchAppWithResetRecordingCount() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetRecordingCount"]
        app.launch()
        return app
    }
}
