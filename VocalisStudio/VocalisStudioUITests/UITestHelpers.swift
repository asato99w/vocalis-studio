//
//  UITestHelpers.swift
//  VocalisStudioUITests
//
//  Common helpers for UI tests
//

import XCTest

extension XCTestCase {
    /// Launch app with recording count reset and animations disabled for UI tests
    func launchAppWithResetRecordingCount() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestResetRecordingCount", "-UITestDisableAnimations"]
        app.launch()
        return app
    }
}
