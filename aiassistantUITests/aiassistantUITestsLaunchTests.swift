//
//  aiassistantUITestsLaunchTests.swift
//  aiassistantUITests
//
//  Created by Gerard Gomez on 2/20/26.
//

import XCTest

final class aiassistantUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-fast-ai",
            "-ui-testing-seed-chat"
        ]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["chat.messageList"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
