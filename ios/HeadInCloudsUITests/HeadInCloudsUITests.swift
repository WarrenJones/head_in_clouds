import XCTest

@MainActor
final class HeadInCloudsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        addSystemAlertHandler()
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing-reset"]
        let environment = ProcessInfo.processInfo.environment
        [
            "HEAD_IN_CLOUDS_API_BASE_URL",
            "HEAD_IN_CLOUDS_EVENTS_URL",
            "HEAD_IN_CLOUDS_SHARE_BASE_URL",
            "HIC_ANALYTICS_SMOKE_RUN_ID"
        ].forEach { key in
            if let value = environment[key], !value.isEmpty {
                application.launchEnvironment[key] = value
            }
        }
        application.launchEnvironment["HIC_WECHAT_DIAGNOSTICS"] = "1"
        app = application
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
        }
        app = nil
    }

    func testFirstRunPrivateCardFlow() throws {
        createPrivateCard(text: "I left one sentence above the clouds.")
        XCTAssertTrue(app.buttons["复制链接并预览落地页"].exists)

        app.buttons["复制链接并预览落地页"].tap()
        XCTAssertTrue(app.staticTexts["一张来自云上的明信片"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["复制转发链接"].exists)
        XCTAssertTrue(app.buttons["添加航班，看同航线"].exists)

        app.buttons["复制转发链接"].tap()
        XCTAssertTrue(app.staticTexts["转发链接已复制，可以粘贴到微信或备忘录。"].waitForExistence(timeout: 5))

        app.buttons["添加航班，看同航线"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))

        tapBack()
        XCTAssertTrue(app.staticTexts["一张来自云上的明信片"].waitForExistence(timeout: 5))

        tapBack()
        XCTAssertTrue(app.staticTexts["分享到"].waitForExistence(timeout: 5))

        tapBack()
        XCTAssertTrue(app.staticTexts["云上明信片"].waitForExistence(timeout: 5))
    }

    func testNativeWeChatShareOpensWeChatWhenEnabled() throws {
        try assertNativeWeChatShareComposerAppears(buttonTitle: "微信", expectedScene: .session)
    }

    func testNativeWeChatMomentsShareOpensWeChatWhenEnabled() throws {
        try assertNativeWeChatShareComposerAppears(buttonTitle: "朋友圈", expectedScene: .timeline)
    }

    func testNativeWeChatLoginCompletesAccountUpgradeWhenEnabled() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Native WeChat login smoke requires a real device with WeChat installed.")
        #endif

        let weChat = XCUIApplication(bundleIdentifier: "com.tencent.xin")
        weChat.terminate()

        completeOnboardingToOpening()
        app.buttons["opening.settings"].tap()
        XCTAssertTrue(app.staticTexts["账号设置"].waitForExistence(timeout: 5))
        app.buttons["保存我的账号"].tap()
        XCTAssertTrue(app.staticTexts["保存你的飞行"].waitForExistence(timeout: 5))

        app.buttons["sign_in.wechat"].tap()

        XCTAssertTrue(
            weChat.wait(for: .runningForeground, timeout: 10),
            "WeChat login should foreground com.tencent.xin for native authorization."
        )
        tapWeChatAuthorizationIfVisible(in: weChat)

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 30),
            "WeChat auth should return to Head in the Clouds after authorization."
        )
        XCTAssertTrue(
            app.staticTexts["已用微信保存"].waitForExistence(timeout: 15) ||
                app.staticTexts["保存好了，所有飞行已同步"].waitForExistence(timeout: 1) ||
                app.staticTexts["找到你之前的账号，已合并飞行记录"].waitForExistence(timeout: 1),
            "WeChat login returned to the app, but did not complete account upgrade."
        )
    }

    private func assertNativeWeChatShareComposerAppears(buttonTitle: String, expectedScene: NativeWeChatShareExpectation) throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Native WeChat share smoke requires a real device with WeChat installed.")
        #endif

        let weChat = XCUIApplication(bundleIdentifier: "com.tencent.xin")
        weChat.terminate()

        createPrivateCard(text: "I am sharing this cloud card through native WeChat \(buttonTitle).")
        XCTAssertTrue(app.staticTexts["分享到"].waitForExistence(timeout: 5))

        app.buttons[buttonTitle].tap()

        XCTAssertTrue(
            weChat.wait(for: .runningForeground, timeout: 10),
            "Native WeChat share should foreground com.tencent.xin instead of staying in the system share sheet."
        )
        Thread.sleep(forTimeInterval: 5)
        guard weChat.state == .runningForeground else {
            print("HIC_WECHAT_UI_DIAGNOSTIC expected=\(expectedScene.rawValue) foreground=false returnedBeforeComposer=true")
            XCTFail("Native WeChat share returned before a friend or Moments share composer became visible for \(buttonTitle).")
            app.activate()
            return
        }
        XCTAssertTrue(
            waitForNativeWeChatComposer(in: weChat, expectedScene: expectedScene, timeout: 8),
            "Native WeChat share opened WeChat, but no friend or Moments share composer became visible for \(buttonTitle)."
        )
        XCTAssertEqual(
            weChat.state,
            .runningForeground,
            "Native WeChat share returned immediately after tapping \(buttonTitle); this is not a completed share handoff."
        )
        app.activate()
    }

    private func waitForNativeWeChatComposer(
        in weChat: XCUIApplication,
        expectedScene: NativeWeChatShareExpectation,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if expectedScene.visible(in: weChat) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        dumpKnownWeChatShareSignals(in: weChat, expectedScene: expectedScene)
        return false
    }

    private func dumpKnownWeChatShareSignals(in weChat: XCUIApplication, expectedScene: NativeWeChatShareExpectation) {
        let knownLabels = [
            "选择一个聊天",
            "发送给朋友",
            "发送",
            "分享到朋友圈",
            "发表",
            "这一刻的想法...",
            "微信",
            "通讯录",
            "发现",
            "我"
        ]
        print("HIC_WECHAT_UI_DIAGNOSTIC expected=\(expectedScene.rawValue) foreground=\(weChat.state == .runningForeground)")
        knownLabels.forEach { label in
            let exists = weChat.descendants(matching: .any)[label].exists
            print("HIC_WECHAT_UI_DIAGNOSTIC label='\(label)' exists=\(exists)")
        }
    }

    private func tapWeChatAuthorizationIfVisible(in weChat: XCUIApplication) {
        let authorizeLabels = [
            "允许",
            "同意",
            "确认登录",
            "授权登录",
            "登录",
            "继续"
        ]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline && weChat.state == .runningForeground {
            for label in authorizeLabels {
                let button = weChat.buttons[label]
                if button.exists && button.isHittable {
                    button.tap()
                    return
                }
                let element = weChat.descendants(matching: .any)[label]
                if element.exists && element.isHittable {
                    element.tap()
                    return
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        dumpKnownWeChatLoginSignals(in: weChat)
    }

    private func dumpKnownWeChatLoginSignals(in weChat: XCUIApplication) {
        let knownLabels = [
            "微信登录",
            "授权登录",
            "允许",
            "同意",
            "确认登录",
            "登录",
            "取消"
        ]
        print("HIC_WECHAT_LOGIN_UI_DIAGNOSTIC foreground=\(weChat.state == .runningForeground)")
        knownLabels.forEach { label in
            let exists = weChat.descendants(matching: .any)[label].exists
            print("HIC_WECHAT_LOGIN_UI_DIAGNOSTIC label='\(label)' exists=\(exists)")
        }
    }

    func testVerifyFlightAndPublishSameFlightFlow() throws {
        relaunch(arguments: ["--ui-testing-reset", "--ui-testing-enable-fixture-proof"])
        createPrivateCard(text: "I am landing with one thing left unsaid.")

        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))

        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "选择票证截图")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["票证截图识别完成：原图不上传，只保留 hash 和可验证字段。"].waitForExistence(timeout: 5))

        app.buttons["确认并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["同班机"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MU5301"].exists)
        XCTAssertTrue(app.buttons["发现同旅程"].exists)
    }

    func testTicketProofButtonsDoNotCreateFixtureFlightInRealMode() throws {
        createPrivateCard(text: "I want real proof, not a local fixture.")

        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["选择票证截图"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["票证截图选择暂未接入；请先手动填写航班号，发布同班机前再验证。"].exists)

        let flightNumberField = app.textFields["add_flight.flight_number"]
        XCTAssertTrue(flightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(flightNumberField)
        flightNumberField.tap()
        flightNumberField.typeText("CA1234")
        XCTAssertEqual(flightNumberField.value as? String, "CA1234")
    }

    func testCardStudioButtonsProvideVisibleFeedback() throws {
        openCardStudio(text: "A button should always prove it worked.")

        app.buttons["保存为草稿"].tap()
        XCTAssertTrue(app.staticTexts["草稿已保存在本机，可返回后继续编辑。"].waitForExistence(timeout: 5))

        app.buttons["高级模板包"].tap()
        XCTAssertTrue(app.staticTexts["让明信片更像一件作品"].waitForExistence(timeout: 5))
    }

    func testComposeKeyboardDismissAndInputModeTabsWork() throws {
        completeOnboardingToOpening()

        app.buttons["opening.write"].tap()
        let editor = app.textViews["compose.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Keyboard should not trap this screen.")

        let dismissKeyboardButton = app.buttons["compose.keyboard.dismiss"]
        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 2))
        dismissKeyboardButton.tap()
        XCTAssertFalse(dismissKeyboardButton.waitForExistence(timeout: 1))

        app.buttons["compose.mode.template"].tap()
        XCTAssertTrue(app.buttons["compose.template.0"].waitForExistence(timeout: 5))

        app.buttons["compose.mode.voice"].tap()
        XCTAssertTrue(app.staticTexts["点按开始录音转文字"].waitForExistence(timeout: 5))
    }

    func testDiscoveryTabsChangeStateAndEmptyCopy() throws {
        completeOnboardingToOpening()

        app.buttons["看看别人留下的"].tap()
        XCTAssertTrue(app.staticTexts["发现"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["还没有真实同旅程内容"].exists)

        app.buttons["discovery.tab.destination"].tap()
        XCTAssertTrue(app.staticTexts["还没有同目的地笔记"].waitForExistence(timeout: 5))

        app.buttons["discovery.tab.trending"].tap()
        XCTAssertTrue(app.staticTexts["热点还没开始"].waitForExistence(timeout: 5))

        app.buttons["discovery.tab.random"].tap()
        XCTAssertTrue(app.staticTexts["随机漫游还没有内容"].waitForExistence(timeout: 5))
    }

    func testOpeningEntryPagesCanReturnAndSettingsRowsShowFeedback() throws {
        completeOnboardingToOpening()

        app.buttons["opening.settings"].tap()
        XCTAssertTrue(app.staticTexts["账号设置"].waitForExistence(timeout: 5))
        scrollToHittable(app.buttons["settings.clear_draft"])
        app.buttons["settings.clear_draft"].tap()
        XCTAssertTrue(waitForFeedback("本机草稿已清除"))
        app.buttons["settings.comments_count"].tap()
        XCTAssertTrue(waitForFeedback("评论统计会在服务端账号同步后更新"))
        tapBack()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))

        app.buttons["添加航班号 / 扫登机牌"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))
        tapBack()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))

        app.buttons["添加登机提醒"].tap()
        XCTAssertTrue(app.buttons["保存登机提醒"].waitForExistence(timeout: 5))
        tapBack()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))

        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "我的飞行册")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["我的飞行册"].waitForExistence(timeout: 5))
        tapBack()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))
    }

    func testCompletedOnboardingRelaunchesToReturningOpeningWithoutReset() throws {
        completeOnboardingToOpening()

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["登机前 30 分钟，给这趟飞行留一句话"].exists)
    }

    func testPublishedPostRelaunchesToReturningOpeningWithoutReset() throws {
        createPrivateCard(text: "Returning users should land on opening after relaunch.")

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["登机前 30 分钟，给这趟飞行留一句话"].exists)
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "我的飞行册 1")).firstMatch.exists)
    }

    func testCardStudioQuoteEditorKeyboardDismissAndPublishBackLoop() throws {
        openCardStudio(text: "The card editor must not trap the keyboard.")

        let quoteEditor = app.textViews["card_studio.quote_editor"]
        XCTAssertTrue(quoteEditor.waitForExistence(timeout: 5))
        quoteEditor.tap()
        quoteEditor.typeText(" More.")

        let dismissKeyboardButton = app.buttons["keyboard.dismiss"]
        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 2))
        dismissKeyboardButton.tap()
        XCTAssertFalse(dismissKeyboardButton.waitForExistence(timeout: 1))

        app.buttons["继续发布"].tap()
        XCTAssertTrue(app.staticTexts["私人明信片已保存"].waitForExistence(timeout: 5))

        tapBack()
        XCTAssertTrue(app.staticTexts["云上明信片"].waitForExistence(timeout: 5))
    }

    func testUITestFixtureResidueIsClearedOnHumanRelaunch() throws {
        relaunch(arguments: ["--ui-testing-reset", "--ui-testing-enable-fixture-proof"])
        createPrivateCard(text: "I am landing with one thing left unsaid.")

        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "选择票证截图")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["票证截图识别完成：原图不上传，只保留 hash 和可验证字段。"].waitForExistence(timeout: 5))
        app.buttons["确认并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["同班机"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MU5301"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["登机前 30 分钟，给这趟飞行留一句话"].exists)
        XCTAssertFalse(app.staticTexts["MU5301"].exists)
        XCTAssertFalse(app.staticTexts["I am landing with one thing left unsaid."].exists)
    }

    func testAddFlightInfoDoesNotPrefillFakeFlightAndCanDismissKeyboard() throws {
        createPrivateCard(text: "I want to add the real flight myself.")

        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))

        let flightNumberField = app.textFields["add_flight.flight_number"]
        XCTAssertTrue(flightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(flightNumberField)
        flightNumberField.tap()
        flightNumberField.typeText("CA1234")
        XCTAssertEqual(flightNumberField.value as? String, "CA1234")

        let routeField = app.textFields["add_flight.route"]
        XCTAssertTrue(routeField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(routeField)
        routeField.tap()
        routeField.typeText("PEK-SZX")
        XCTAssertEqual(routeField.value as? String, "PEK-SZX")

        let dismissKeyboardButton = app.buttons["keyboard.dismiss"]
        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 2))
        dismissKeyboardButton.tap()
        XCTAssertFalse(dismissKeyboardButton.waitForExistence(timeout: 1))
    }

    func testFlightReminderDoesNotPrefillFakeFlightAndCanDismissKeyboard() throws {
        completeOnboardingToOpening()

        app.buttons["添加登机提醒"].tap()
        XCTAssertTrue(app.buttons["保存登机提醒"].waitForExistence(timeout: 5))

        let flightNumberField = app.textFields["reminder.flight_number"]
        XCTAssertTrue(flightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(flightNumberField)
        flightNumberField.tap()
        flightNumberField.typeText("CA1234")
        XCTAssertEqual(flightNumberField.value as? String, "CA1234")

        let routeField = app.textFields["reminder.route"]
        XCTAssertTrue(routeField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(routeField)
        routeField.tap()
        routeField.typeText("PEK-SZX")
        XCTAssertEqual(routeField.value as? String, "PEK-SZX")

        let dismissKeyboardButton = app.buttons["keyboard.dismiss"]
        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 2))
        dismissKeyboardButton.tap()
        XCTAssertFalse(dismissKeyboardButton.waitForExistence(timeout: 1))
    }

    func testLegacyFixtureFlightStateIsDiscardedBeforeFlightFormsHydrate() throws {
        app.terminate()
        app.launchArguments = ["--ui-testing-reset", "--ui-testing-seed-legacy-fixture-flight"]
        app.launch()

        completeOnboardingToOpening()

        app.buttons["添加登机提醒"].tap()
        XCTAssertTrue(app.buttons["保存登机提醒"].waitForExistence(timeout: 5))
        let reminderFlightNumberField = app.textFields["reminder.flight_number"]
        XCTAssertTrue(reminderFlightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(reminderFlightNumberField)
        reminderFlightNumberField.tap()
        reminderFlightNumberField.typeText("CA1234")
        XCTAssertEqual(reminderFlightNumberField.value as? String, "CA1234")

        let dismissKeyboardButton = app.buttons["keyboard.dismiss"]
        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 2))
        dismissKeyboardButton.tap()
        XCTAssertFalse(dismissKeyboardButton.waitForExistence(timeout: 1))

        app.terminate()
        app.launchArguments = ["--ui-testing-reset", "--ui-testing-seed-legacy-fixture-flight"]
        app.launch()
        completeOnboardingToOpening()
        createPrivateCardFromOpening(text: "I am checking a migrated app state.")
        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))
        let addFlightNumberField = app.textFields["add_flight.flight_number"]
        XCTAssertTrue(addFlightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(addFlightNumberField)
        addFlightNumberField.tap()
        addFlightNumberField.typeText("CA9876")
        XCTAssertEqual(addFlightNumberField.value as? String, "CA9876")
    }

    func testFlightFormsDoNotHydrateFromExistingCurrentFlightContext() throws {
        app.terminate()
        app.launchArguments = ["--ui-testing-reset", "--ui-testing-seed-current-flight"]
        app.launch()

        completeOnboardingToOpening()

        app.buttons["添加登机提醒"].tap()
        XCTAssertTrue(app.buttons["保存登机提醒"].waitForExistence(timeout: 5))
        let reminderFlightNumberField = app.textFields["reminder.flight_number"]
        XCTAssertTrue(reminderFlightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(reminderFlightNumberField)

        let reminderRouteField = app.textFields["reminder.route"]
        XCTAssertTrue(reminderRouteField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(reminderRouteField)

        tapBack()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))

        createPrivateCardFromOpening(text: "I should not inherit the old flight in the form.")
        app.buttons["验证航班并发布到同班机"].tap()
        XCTAssertTrue(app.staticTexts["航班信息"].waitForExistence(timeout: 5))

        let addFlightNumberField = app.textFields["add_flight.flight_number"]
        XCTAssertTrue(addFlightNumberField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(addFlightNumberField)

        let addRouteField = app.textFields["add_flight.route"]
        XCTAssertTrue(addRouteField.waitForExistence(timeout: 5))
        assertFieldDoesNotContainFlightFixtures(addRouteField)
    }

    private func completeOnboardingToOpening() {
        XCTAssertTrue(app.staticTexts["登机前 30 分钟，给这趟飞行留一句话"].waitForExistence(timeout: 8))

        app.buttons["welcome.write"].tap()
        dismissSystemAlertIfNeeded()
        XCTAssertTrue(app.buttons["继续，不现在授权"].waitForExistence(timeout: 5))

        app.buttons["继续，不现在授权"].tap()
        XCTAssertTrue(app.buttons["我知道了，继续"].waitForExistence(timeout: 5))

        app.buttons["我知道了，继续"].tap()
        XCTAssertTrue(app.buttons["开始我的第一次飞行"].waitForExistence(timeout: 5))

        app.buttons["开始我的第一次飞行"].tap()
        XCTAssertTrue(app.staticTexts["一句话就够，航班信息可以稍后补"].waitForExistence(timeout: 5))
    }

    private nonisolated func addSystemAlertHandler() {
        addUIInterruptionMonitor(withDescription: "System permission alerts") { alert in
            let denyLabels = [
                "不允许",
                "Don’t Allow",
                "Don't Allow",
                "稍后",
                "Not Now",
                "取消",
                "Cancel"
            ]
            for label in denyLabels where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            if alert.buttons.count > 0 {
                alert.buttons.element(boundBy: 0).tap()
                return true
            }
            return false
        }
    }

    private func dismissSystemAlertIfNeeded() {
        // UI interruption monitors run on the next app interaction.
        app.tap()
    }

    private func relaunch(arguments: [String]) {
        app.terminate()
        app.launchArguments = arguments
        app.launch()
    }

    private func createPrivateCard(text: String) {
        completeOnboardingToOpening()
        createPrivateCardFromOpening(text: text)
    }

    private func openCardStudio(text: String) {
        completeOnboardingToOpening()
        app.buttons["opening.write"].tap()
        let editor = app.textViews["compose.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(text)

        app.buttons["生成私人明信片"].tap()
        XCTAssertTrue(app.staticTexts["云上明信片"].waitForExistence(timeout: 5))
    }

    private func createPrivateCardFromOpening(text: String) {
        app.buttons["opening.write"].tap()
        let editor = app.textViews["compose.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(text)

        app.buttons["生成私人明信片"].tap()
        XCTAssertTrue(app.staticTexts["云上明信片"].waitForExistence(timeout: 5))

        app.buttons["继续发布"].tap()
        XCTAssertTrue(app.staticTexts["私人明信片已保存"].waitForExistence(timeout: 5))
    }

    private func assertFieldDoesNotContainFlightFixtures(_ field: XCUIElement) {
        let value = (field.value as? String) ?? ""
        ["MU5301", "SHA", "CTU", "CA9999", "PVG", "HAK"].forEach { fixture in
            XCTAssertFalse(
                value.localizedCaseInsensitiveContains(fixture),
                "Field should be empty or placeholder-only, but contained fixture/current flight value: \(value)"
            )
        }
    }

    private func scrollToHittable(_ element: XCUIElement, maxSwipes: Int = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        for _ in 0..<maxSwipes where !element.isHittable {
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func tapBack(timeout: TimeInterval = 5) {
        let backButton = app.buttons["nav.back"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: timeout))
        let deadline = Date().addingTimeInterval(timeout)
        while !backButton.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(backButton.isHittable)
        backButton.tap()
    }

    private func waitForFeedback(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let toast = app.descendants(matching: .any)["feedback.toast"]
        guard toast.waitForExistence(timeout: timeout) else {
            return false
        }
        let predicate = NSPredicate(format: "label == %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: toast)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

private enum NativeWeChatShareExpectation: String {
    case session
    case timeline

    func visible(in weChat: XCUIApplication) -> Bool {
        switch self {
        case .session:
            return [
                "选择一个聊天",
                "发送给朋友",
                "发送"
            ].contains { weChat.descendants(matching: .any)[$0].exists }
        case .timeline:
            return [
                "分享到朋友圈",
                "这一刻的想法...",
                "发表"
            ].contains { weChat.descendants(matching: .any)[$0].exists }
        }
    }
}
