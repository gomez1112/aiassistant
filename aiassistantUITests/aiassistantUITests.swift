//
//  aiassistantUITests.swift
//  aiassistantUITests
//
//  Created by Gerard Gomez on 2/20/26.
//

import XCTest

final class aiassistantUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testComposerFocusSendAndReplyVisibility() throws {
        launchApp()

        let input = element("chat.composer.input")
        XCTAssertTrue(input.waitForExistence(timeout: 5))

        input.tap()
        let composerFrameAfterFocus = input.frame
        let keyboard = app.keyboards.firstMatch
        if keyboard.waitForExistence(timeout: 2) {
            XCTAssertLessThanOrEqual(composerFrameAfterFocus.maxY, keyboard.frame.minY + 1)
        }
        input.typeText("Please make this a short keyboard QA checklist.")

        let sendButton = element("chat.composer.send")
        XCTAssertTrue(sendButton.waitForExistence(timeout: 2))
        sendButton.tap()

        let reply = element("chat.message.assistant")
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        let replyValue = reply.value as? String ?? ""
        XCTAssertTrue(replyValue.contains("UI test reply"))
        XCTAssertTrue(element("chat.composer.input").exists)
        XCTAssertTrue(element("chat.messageList").exists)
        XCTAssertLessThanOrEqual(reply.frame.maxY, element("chat.composer.input").frame.minY + 24)
    }

    @MainActor
    func testCompactChromeCollapsesWhileTypingAndRestoresOnDismiss() throws {
        launchApp()

        XCTAssertTrue(element("chat.emptyState").waitForExistence(timeout: 5))
        XCTAssertTrue(element("chat.upgradeTeaser").exists)

        let input = element("chat.composer.input")
        input.tap()

        XCTAssertTrue(element("chat.mode.compactMenu").waitForExistence(timeout: 2))
        XCTAssertFalse(element("chat.upgradeTeaser").exists)

        element("chat.emptyState").tap()

        XCTAssertTrue(element("chat.upgradeTeaser").waitForExistence(timeout: 3))
    }

    @MainActor
    func testThreadListNavigationDismissesComposerFocus() throws {
        launchApp(arguments: ["-ui-testing-seed-chat"])

        XCTAssertTrue(element("chat.messageList").waitForExistence(timeout: 5))
        element("chat.composer.input").tap()
        element("chat.toolbar.threads").tap()

        XCTAssertTrue(element("threadList.sheet").waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["threadList.newChat"].waitForExistence(timeout: 2))
        app.buttons["threadList.newChat"].tap()

        XCTAssertTrue(element("chat.emptyState").waitForExistence(timeout: 3))
        XCTAssertTrue(element("chat.composer.input").exists)
    }

    @MainActor
    func testCompactModeAndAssistantActionsAreReachable() throws {
        launchApp(arguments: ["-ui-testing-seed-chat"])

        let modeMenu = element("chat.mode.compactMenu")
        XCTAssertTrue(modeMenu.waitForExistence(timeout: 2))
        modeMenu.tap()
        XCTAssertTrue(app.buttons["Write"].waitForExistence(timeout: 2))
        app.buttons["Write"].tap()

        let actionsMenu = element("chat.messageActions.menu")
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 2))
        actionsMenu.tap()

        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons["Transform"].exists)
    }

    @MainActor
    func testPaywallProductStateIsReachableUnderUITesting() throws {
        launchApp()

        let upgrade = element("chat.upgradeTeaser")
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()

        XCTAssertTrue(app.navigationBars["Upgrade"].waitForExistence(timeout: 5))
        let yearlyPlan = element("paywall.plan.com.transfinite.aiassistant.premium.yearly")
        let retry = element("paywall.plans.retry")
        XCTAssertTrue(yearlyPlan.waitForExistence(timeout: 5) || retry.waitForExistence(timeout: 1))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
        }
    }

    @MainActor
    private func launchApp(arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-fast-ai"
        ] + arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
