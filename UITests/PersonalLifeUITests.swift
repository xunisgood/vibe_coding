import Carbon
import XCTest

final class PersonalLifeUITests: XCTestCase {
  var app: XCUIApplication!
  var dataDirectory: String!
  var originalInputSource: TISInputSource?
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(bundleIdentifier: "com.xunisgood.personallife.uitestapp")
    dataDirectory = NSTemporaryDirectory() + "PersonalLife-UI-" + UUID().uuidString
    app.launchArguments = ["--data-directory", dataDirectory]
    app.launch()
    originalInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    XCTAssertEqual(
      TISSelectInputSource(TISCopyCurrentASCIICapableKeyboardInputSource().takeRetainedValue()),
      noErr)
    XCTAssertTrue(app.buttons["nav-0"].waitForExistence(timeout: 15), app.debugDescription)
  }
  override func tearDownWithError() throws {
    if testRun?.failureCount ?? 0 > 0 {
      let a = XCTAttachment(string: app.debugDescription)
      a.lifetime = .keepAlways
      add(a)
    }
    app.terminate()
    if let originalInputSource { XCTAssertEqual(TISSelectInputSource(originalInputSource), noErr) }
  }
  func click(_ label: String) {
    let b = app.buttons[label].firstMatch
    XCTAssertTrue(b.waitForExistence(timeout: 5), app.debugDescription)
    b.click()
  }
  func screenshot(_ name: String) {
    let a = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
    a.name = name
    a.lifetime = .keepAlways
    add(a)
  }
  func testAllPagesAndEmptyStates() {
    for i in 0...7 {
      click("nav-\(i)")
      screenshot("empty-page-\(i)")
    }
    XCTAssertTrue(app.staticTexts["本地数据"].exists)
  }
  func expandCompleted() {
    let disclosure = app.disclosureTriangles["已完成"]
    XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
    if (disclosure.value as? NSNumber)?.intValue == 0 {
      disclosure.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).click()
    }
    XCTAssertEqual((disclosure.value as? NSNumber)?.intValue, 1, app.debugDescription)
  }
  func testTodoCompletionUndoAndRelaunch() {
    click("nav-1")
    let field = app.textFields["todo-input"]
    field.click()
    field.typeText("UI-test-task")
    field.typeKey(.tab, modifierFlags: [])
    click("添加")
    XCTAssertTrue(
      app.staticTexts["UI-test-task"].waitForExistence(timeout: 5), app.debugDescription)
    click("详情")
    XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3))
    click("保存")
    app.checkBoxes["完成"].firstMatch.click()
    expandCompleted()
    screenshot("todo-completed-expanded")
    XCTAssertTrue(
      app.staticTexts["UI-test-task"].waitForExistence(timeout: 5), app.debugDescription)
    click("删除")
    XCTAssertFalse(app.staticTexts["UI-test-task"].exists)
    click("撤销")
    expandCompleted()
    XCTAssertTrue(app.staticTexts["UI-test-task"].exists)
    app.terminate()
    app.launch()
    click("nav-1")
    expandCompleted()
    XCTAssertTrue(app.staticTexts["UI-test-task"].waitForExistence(timeout: 5))
    screenshot("todo-reloaded")
  }
  func testGameRecordPersistsAndHomeUpdates() {
    click("nav-5")
    click("记录游戏")
    let name = app.textFields["游戏名称（必填）"]
    XCTAssertTrue(name.waitForExistence(timeout: 3), app.debugDescription)
    name.click()
    name.typeText("UI-test-game")
    name.typeKey(.tab, modifierFlags: [])
    enter("分钟", "60")
    click("保存")
    XCTAssertTrue(app.staticTexts["请输入有效时长：小时为非负整数，分钟为 0–59，总时长大于零"].exists)
    XCTAssertTrue(app.sheets.firstMatch.exists)
    enter("分钟", "30")
    click("保存")
    XCTAssertTrue(
      app.staticTexts["UI-test-game"].waitForExistence(timeout: 3), app.debugDescription)
    click("nav-0")
    XCTAssertTrue(app.staticTexts["今天玩了 30 分钟"].waitForExistence(timeout: 3), app.debugDescription)
    screenshot("home-game-summary")
  }
  func enter(_ label: String, _ value: String) {
    let f = app.textFields[label].firstMatch
    XCTAssertTrue(f.waitForExistence(timeout: 5), app.debugDescription)
    f.click()
    f.typeKey("a", modifierFlags: .command)
    f.typeText(value)
    f.typeKey(.tab, modifierFlags: [])
  }
  func testTrainingAppearsInTodayAndActualSetSurvivesRelaunch() {
    click("nav-3")
    click("新建训练安排")
    enter("训练名称（必填）", "UI-training")
    click("添加动作")
    enter("动作名称", "Squat")
    click("保存安排")
    click("记录一组")
    enter("次数", "8")
    enter("重量", "20")
    click("完成训练")
    click("nav-1")
    XCTAssertTrue(app.staticTexts["UI-training"].exists, app.debugDescription)
    XCTAssertTrue(app.staticTexts["已完成"].exists)
    app.terminate()
    app.launch()
    click("nav-3")
    XCTAssertEqual(app.textFields["次数"].firstMatch.value as? String, "8")
    XCTAssertEqual(app.textFields["重量"].firstMatch.value as? String, "20")
    XCTAssertTrue(app.staticTexts["已完成"].exists)
    screenshot("training-reloaded")
  }
  func testProjectTaskArchiveAndRestore() {
    click("nav-2")
    click("新建项目")
    enter("项目名称（必填）", "UI-project")
    click("保存")
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI-project")).firstMatch
      .click()
    click("添加任务")
    enter("标题（必填）", "UI-development-task")
    click("保存")
    XCTAssertTrue(app.staticTexts["UI-development-task"].exists)
    click("归档")
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI-project")).firstMatch
        .exists)
    app.checkBoxes["查看归档"].click()
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI-project")).firstMatch
      .click()
    XCTAssertTrue(app.staticTexts["UI-development-task"].exists)
    click("恢复")
    app.checkBoxes["查看归档"].click()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI-project")).firstMatch
        .exists)
    screenshot("project-restored")
  }
  func testNoteAutosaveSearchAndRelaunch() {
    click("nav-6")
    click("新建")
    enter("标题", "UI-note")
    let body = app.textViews.firstMatch
    body.click()
    body.typeText("unique-body-query")
    click("nav-0")
    click("nav-6")
    app.terminate()
    app.launch()
    click("nav-6")
    enter("搜索标题和正文", "unique-body-query")
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI-note")).firstMatch.exists,
      app.debugDescription)
    XCTAssertEqual(
      (app.textViews.firstMatch.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      "unique-body-query")
    screenshot("note-body-search")
  }
  func testMealPlanActualAndUndo() {
    click("nav-4")
    enter("可选", "Egg and milk")
    click("按计划吃了")
    XCTAssertEqual(app.textFields["未记录"].firstMatch.value as? String, "Egg and milk")
    XCTAssertTrue(app.staticTexts["已记录 1 餐"].exists)
    click("清除本餐")
    XCTAssertTrue(app.staticTexts["已记录 0 餐"].exists)
    click("撤销")
    XCTAssertEqual(app.textFields["未记录"].firstMatch.value as? String, "Egg and milk")
    app.terminate()
    app.launch()
    click("nav-4")
    XCTAssertEqual(app.textFields["未记录"].firstMatch.value as? String, "Egg and milk")
    screenshot("meal-reloaded")
  }
  func testMemoConvertsToTodoAndBackup() throws {
    enter("随手记下一个想法…", "UI-memo")
    click("保存备忘")
    click("转为待办")
    click("nav-1")
    XCTAssertTrue(app.staticTexts["UI-memo"].exists, app.debugDescription)
    click("nav-7")
    click("立即备份")
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "备份成功")).firstMatch
        .waitForExistence(timeout: 5), app.debugDescription)
    screenshot("manual-backup")
    let backups = try FileManager.default.contentsOfDirectory(atPath: dataDirectory + "/Backups")
    let backup = try XCTUnwrap(backups.first { $0.hasPrefix("manual-") })
    click("nav-1")
    click("删除")
    XCTAssertFalse(app.staticTexts["UI-memo"].exists)
    click("nav-7")
    click("从备份恢复")
    app.typeKey("g", modifierFlags: [.command, .shift])
    let path = app.sheets.textFields.firstMatch
    XCTAssertTrue(path.waitForExistence(timeout: 5), app.debugDescription)
    path.typeText(dataDirectory + "/Backups/" + backup)
    path.typeKey(.return, modifierFlags: [])
    click("打开")
    click("确认")
    click("nav-1")
    XCTAssertTrue(app.staticTexts["UI-memo"].exists, app.debugDescription)
    screenshot("backup-restored")
  }
  func testChineseLongTitleCompactWindowAndDockReopen() {
    let window = app.windows.firstMatch
    let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(
      CGVector(dx: -2, dy: -2))
    corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -220, dy: -140)))
    XCTAssertLessThanOrEqual(window.frame.width, 900)
    click("nav-1")
    let title = "学习记录：今天阅读并整理笔记，完成训练之后复盘开发进度，保留中文标点和长标题。"
    enter("todo-input", title)
    click("添加")
    XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), app.debugDescription)
    screenshot("compact-chinese-title")
    window.buttons["_XCUI:CloseWindow"].click()
    XCTAssertNotEqual(app.state, .notRunning)
    XCTAssertFalse(app.windows.firstMatch.exists)
    let dock = XCUIApplication(bundleIdentifier: "com.apple.dock")
    let icon = dock.descendants(matching: .any).matching(
      NSPredicate(format: "title == %@", "PersonalLife")
    ).firstMatch
    XCTAssertTrue(icon.waitForExistence(timeout: 5), dock.debugDescription)
    icon.click()
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[title].exists)
    screenshot("dock-reopened")
  }
}
