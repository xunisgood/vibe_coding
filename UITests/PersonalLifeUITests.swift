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
    originalInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    app.launch()
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
    if label.hasPrefix("nav-"), app.windows["设置与数据"].exists {
      app.windows["设置与数据"].buttons["_XCUI:CloseWindow"].click()
    }
    let b = app.buttons[label].firstMatch
    XCTAssertTrue(b.waitForExistence(timeout: 5), app.debugDescription)
    b.click()
  }
  func screenshot(_ name: String) {
    app.activate()
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
  func testToolbarCommandsAndSidebar() {
    click("nav-6")
    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(app.textFields["标题"].waitForExistence(timeout: 5))
    enter("标题", "Keyboard note")
    app.typeKey("f", modifierFlags: .command)
    app.typeText("Keyboard")
    XCTAssertEqual(app.textFields["搜索标题和正文"].value as? String, "Keyboard")
    click("toggle-sidebar")
    XCTAssertFalse(app.buttons["nav-0"].exists)
    app.typeKey("s", modifierFlags: [.command, .option])
    XCTAssertTrue(app.buttons["nav-0"].waitForExistence(timeout: 5))
    click("nav-1")
    app.typeKey("n", modifierFlags: .command)
    app.typeText("Keyboard task")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(app.staticTexts["Keyboard task"].exists)
    screenshot("fixed-toolbar-keyboard")
  }
  func testNotesKeyboardSelectionAndIndependentScrolling() {
    click("nav-6")
    app.typeKey("n", modifierFlags: .command)
    app.typeText("Older")
    app.textViews.firstMatch.click()
    app.textViews.firstMatch.typeText(String(repeating: "Long body line\n", count: 45))
    app.typeKey("n", modifierFlags: .command)
    app.typeText("Newer")
    let newer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Newer")).firstMatch
    newer.click()
    app.typeKey(.downArrow, modifierFlags: [])
    XCTAssertEqual(app.textFields["标题"].value as? String, "Older")
    let searchFrame = app.textFields["搜索标题和正文"].frame
    app.textViews.firstMatch.scroll(byDeltaX: 0, deltaY: -600)
    XCTAssertEqual(app.textFields["搜索标题和正文"].frame, searchFrame)
    XCTAssertTrue(newer.isHittable)
    app.typeKey(.upArrow, modifierFlags: [])
    XCTAssertEqual(app.textFields["标题"].value as? String, "Newer")
    click("nav-0")
    click("nav-6")
    XCTAssertEqual(app.textFields["标题"].value as? String, "Newer")
    screenshot("notes-independent-workspace")
  }
  func testWideTodoDraftSurvivesResizeAndGuardsNavigation() {
    click("nav-1")
    enter("todo-input", "Draft task")
    click("添加")
    click("toggle-sidebar")
    click("详情")
    XCTAssertFalse(app.sheets.firstMatch.exists)
    XCTAssertTrue(app.staticTexts["待办详情"].exists)
    screenshot("wide-todo-inspector")
    enter("名称（必填）", "Draft changed")
    click("toggle-sidebar")
    XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["名称（必填）"].value as? String, "Draft changed")
    click("保存")
    XCTAssertTrue(app.staticTexts["Draft changed"].exists)
    click("toggle-sidebar")
    click("详情")
    enter("名称（必填）", "Discard this")
    click("toggle-sidebar")
    // In the narrow sheet, Cancel discards only the current draft.
    click("取消")
    XCTAssertTrue(app.staticTexts["Draft changed"].exists)
    XCTAssertFalse(app.staticTexts["Discard this"].exists)
    click("toggle-sidebar")
    click("详情")
    enter("名称（必填）", "Saved on exit")
    app.typeKey("q", modifierFlags: .command)
    click("继续编辑")
    XCTAssertEqual(app.textFields["名称（必填）"].value as? String, "Saved on exit")
    app.typeKey("q", modifierFlags: .command)
    click("保存修改")
    XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    app.launch()
    // The collapsed sidebar is now restored across launch.
    if !app.buttons["nav-1"].exists { click("toggle-sidebar") }
    click("nav-1")
    XCTAssertTrue(app.staticTexts["Saved on exit"].exists)
  }
  func testWorkspaceRestorationAndIndependentSettings() {
    click("nav-6")
    click("新建")
    enter("标题", "Remember selection")
    let main = app.windows["我的日常"]
    let corner = main.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(
      CGVector(dx: -2, dy: -2))
    corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -100, dy: -80)))
    let size = main.frame.size
    app.typeKey(",", modifierFlags: .command)
    XCTAssertTrue(app.windows["设置与数据"].waitForExistence(timeout: 5))
    XCTAssertTrue(main.exists)
    XCTAssertTrue(app.windows["设置与数据"].staticTexts["本地数据"].exists)
    app.windows["设置与数据"].buttons["_XCUI:CloseWindow"].click()
    XCTAssertEqual(app.textFields["标题"].value as? String, "Remember selection")
    click("toggle-sidebar")
    app.terminate()
    app.launch()
    XCTAssertFalse(app.buttons["nav-0"].exists)
    XCTAssertEqual(app.textFields["标题"].value as? String, "Remember selection")
    XCTAssertEqual(app.windows["我的日常"].frame.width, size.width, accuracy: 2)
    XCTAssertEqual(app.windows["我的日常"].frame.height, size.height, accuracy: 2)
    click("toggle-sidebar")
    screenshot("restored-workspace")
  }
  func testReducedEffectsContextMenuAndSafeTextDeletion() {
    app.terminate()
    app.launchArguments += ["--ui-reduced-effects"]
    app.launch()
    click("nav-6")
    app.typeKey("n", modifierFlags: .command)
    app.typeText("Typing")
    let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Typing")).firstMatch
    row.rightClick()
    app.menuItems["重命名"].click()
    app.typeKey("a", modifierFlags: .command)
    app.typeText("Renamed")
    app.typeKey(.delete, modifierFlags: [])
    XCTAssertEqual(app.textFields["标题"].value as? String, "Rename")
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Rename")).firstMatch.exists)
    screenshot("reduced-effects-context-menu")
  }
  func testGameFilterKeepsDailyTotalAndRecords() {
    click("nav-5")
    for name in ["Alpha", "Beta"] {
      app.typeKey("n", modifierFlags: .command)
      enter("游戏名称（必填）", name)
      click("保存")
    }
    XCTAssertTrue(app.staticTexts["今日游戏：60 分钟"].exists)
    app.typeKey("f", modifierFlags: .command)
    app.typeText("Alpha")
    XCTAssertTrue(app.staticTexts["Alpha"].exists)
    XCTAssertFalse(app.staticTexts["Beta"].exists)
    XCTAssertTrue(app.staticTexts["今日游戏：60 分钟"].exists)
    enter("搜索游戏名称", "Missing")
    XCTAssertTrue(app.staticTexts["没有匹配的游戏"].exists)
    enter("搜索游戏名称", "")
    XCTAssertTrue(app.staticTexts["Alpha"].exists)
    XCTAssertTrue(app.staticTexts["Beta"].exists)
  }
  func testIconActionsKeepAccessibleNamesAndNoteDeletionUndo() {
    click("nav-6")
    let create = app.buttons["新建"]
    XCTAssertTrue(create.isHittable)
    XCTAssertEqual(create.staticTexts.count, 0)
    click("新建")
    enter("标题", "Icon-note")
    let delete = app.buttons["删除笔记"]
    XCTAssertTrue(delete.isHittable)
    XCTAssertEqual(delete.staticTexts.count, 0)
    screenshot("note-icon-actions")
    click("删除笔记")
    XCTAssertFalse(app.textFields["标题"].exists)
    click("撤销")
    let note = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Icon-note"))
      .firstMatch
    XCTAssertTrue(note.exists)
    // This test isolates the icon actions; the row hit area has its own regression test.
    note.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).click()
    XCTAssertEqual(app.textFields["标题"].value as? String, "Icon-note")
  }
  func expandCompleted() {
    let toggle = app.buttons["completed-toggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    if (toggle.value as? String) == "收起" { toggle.click() }
    XCTAssertEqual(toggle.value as? String, "展开", app.debugDescription)
  }
  func testNoteRowBlankAreaSelectsAndPreservesEdits() {
    click("nav-6")
    click("新建")
    enter("标题", "First")
    app.textViews.firstMatch.click()
    app.textViews.firstMatch.typeText("First body")
    click("新建")
    enter("标题", "Second")
    let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "First、"))
      .firstMatch
    XCTAssertTrue(first.exists)
    // Hit the padded empty right edge, away from both title and timestamp.
    first.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).click()
    XCTAssertEqual(app.textFields["标题"].value as? String, "First")
    XCTAssertEqual(app.textViews.firstMatch.value as? String, "First body")
    enter("标题", "First edited")
    let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Second、"))
      .firstMatch
    second.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).click()
    XCTAssertEqual(app.textFields["标题"].value as? String, "Second")
    app.terminate()
    app.launch()
    click("nav-6")
    let restored = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "First edited"))
      .firstMatch
    restored.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).click()
    XCTAssertEqual(app.textFields["标题"].value as? String, "First edited")
    XCTAssertEqual(app.textViews.firstMatch.value as? String, "First body")
    screenshot("note-full-row-selection")
  }
  func testEarlierTodoVisibleAndEditableAfterRelaunch() throws {
    click("nav-1")
    enter("todo-input", "Yesterday pending")
    click("添加")
    app.terminate()
    let file = URL(fileURLWithPath: dataDirectory).appendingPathComponent("library.json")
    var library = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    var todos = try XCTUnwrap(library["todos"] as? [[String: Any]])
    let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    todos[0]["day"] = formatter.string(from: yesterday)
    library["todos"] = todos
    try JSONSerialization.data(withJSONObject: library).write(to: file, options: .atomic)
    app.launch()
    click("nav-1")
    let row = app.descendants(matching: .any).matching(identifier: "earlier-open-Yesterday pending")
      .firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    XCTAssertTrue(
      row.isHittable, "Yesterday's unfinished task must be visible without expanding a group")
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).click()
    XCTAssertEqual(app.textFields["名称（必填）"].value as? String, "Yesterday pending")
    enter("名称（必填）", "Yesterday edited")
    click("保存")
    XCTAssertTrue(app.staticTexts["Yesterday edited"].exists)
    click("移到今天")
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "todo-open-Yesterday edited").firstMatch
        .exists)
    XCTAssertEqual((app.checkBoxes["完成"].firstMatch.value as? NSNumber)?.intValue, 0)
    app.terminate()
    app.launch()
    click("nav-1")
    XCTAssertTrue(app.staticTexts["Yesterday edited"].exists)
    screenshot("earlier-todo-visible")
  }
  func testPendingTodoRowOpensDetailsWithoutCompleting() {
    click("nav-1")
    enter("todo-input", "Pending")
    click("添加")
    let row = app.descendants(matching: .any).matching(identifier: "todo-open-Pending").firstMatch
    XCTAssertTrue(row.exists)
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).click()
    XCTAssertTrue(app.staticTexts["待办详情"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["名称（必填）"].value as? String, "Pending")
    enter("名称（必填）", "Pending edited")
    app.textViews.firstMatch.click()
    app.textViews.firstMatch.typeText("Keep this detail")
    click("保存")
    XCTAssertEqual((app.checkBoxes["完成"].firstMatch.value as? NSNumber)?.intValue, 0)
    app.terminate()
    app.launch()
    click("nav-1")
    let restored = app.descendants(matching: .any).matching(identifier: "todo-open-Pending edited")
      .firstMatch
    restored.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).click()
    XCTAssertEqual(app.textViews.firstMatch.value as? String, "Keep this detail")
    screenshot("pending-todo-details")
    click("取消")
    XCTAssertEqual((app.checkBoxes["完成"].firstMatch.value as? NSNumber)?.intValue, 0)
    app.checkBoxes["完成"].firstMatch.click()
    expandCompleted()
    XCTAssertEqual((app.checkBoxes["完成"].firstMatch.value as? NSNumber)?.intValue, 1)
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
    if value.isEmpty { f.typeKey(.delete, modifierFlags: []) } else { f.typeText(value) }
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
    app.activate()
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
    path.click()
    path.typeKey("a", modifierFlags: [.command])
    let backupPath = dataDirectory + "/Backups/" + backup
    path.typeText(backupPath)
    XCTAssertEqual(path.value as? String, backupPath)
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
  func testSidebarAlignmentAndDarkAppearance() {
    let first = app.buttons["nav-0"].frame
    for i in 0...7 {
      let row = app.buttons["nav-\(i)"]
      XCTAssertEqual(row.frame.minX, first.minX, accuracy: 1)
      XCTAssertEqual(row.frame.width, first.width, accuracy: 1)
      XCTAssertTrue(row.isHittable)
    }
    app.terminate()
    app.launchArguments += ["--ui-appearance", "dark"]
    app.launch()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(identifier: "life-root-dark").firstMatch
        .waitForExistence(timeout: 5), app.debugDescription)
    for i in [0, 2, 3, 4, 5, 6, 7] {
      click("nav-\(i)")
      screenshot("dark-page-\(i)")
    }
  }
  func testCompactLayoutAcrossEveryModule() {
    let window = app.windows.firstMatch
    let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
      .withOffset(CGVector(dx: -2, dy: -2))
    corner.click(forDuration: 0.2, thenDragTo: corner.withOffset(CGVector(dx: -220, dy: -140)))
    for i in 0...7 {
      click("nav-\(i)")
      XCTAssertLessThanOrEqual(window.frame.width, 900)
      if i == 7 {
        XCTAssertTrue(app.windows["设置与数据"].staticTexts["本地数据"].exists)
        screenshot("compact-page-7")
        app.windows["设置与数据"].buttons["_XCUI:CloseWindow"].click()
      } else {
        screenshot("compact-page-\(i)")
      }
      XCTAssertTrue(app.buttons["nav-7"].isHittable)
    }
    click("nav-7")
    XCTAssertTrue(app.staticTexts["本地数据"].exists)
  }
}
