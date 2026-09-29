import LifeCore
import XCTest

@testable import LifeApp

final class AppModelTests: XCTestCase {
  @MainActor func testSaveFailureRetainsEditsAndRetryPersists() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    m.store.beforeReplace = { throw LifeError("磁盘失败") }
    XCTAssertFalse(m.change { $0.todos.append(Todo(title: "保留输入", day: "2026-09-29")) })
    XCTAssertTrue(m.dirty)
    XCTAssertEqual(m.library.todos[0].title, "保留输入")
    XCTAssertTrue(m.status.contains("失败"))
    m.store.beforeReplace = nil
    XCTAssertTrue(m.save())
    XCTAssertFalse(m.dirty)
    XCTAssertEqual(try m.store.load().todos, m.library.todos)
  }
  @MainActor func testCorruptStartupBlocksOrdinaryWrites() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("library.json")
    let bad = Data("broken".utf8)
    try bad.write(to: file)
    let m = AppModel(directory: dir)
    XCTAssertTrue(m.locked)
    XCTAssertFalse(m.change { $0.todos.append(Todo(title: "no", day: "2026-09-29")) })
    XCTAssertEqual(try Data(contentsOf: file), bad)
  }
  @MainActor func testUndoDeletionKeepsUnrelatedLaterChanges() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    let t = Todo(title: "one", day: "2026-09-29")
    XCTAssertTrue(m.change { $0.todos = [t] })
    m.delete({ $0.todos = [] }, undo: { $0.todos.append(t) })
    XCTAssertTrue(m.change { $0.games.append(Game(day: "2026-09-29", name: "test", minutes: 10)) })
    m.undo()
    XCTAssertEqual(m.library.todos, [t])
    XCTAssertEqual(m.library.games.count, 1)
    XCTAssertEqual(try m.store.load(), m.library)
  }
  @MainActor func testViewingOldDateStillMaterializesToday() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    var p = TrainingPlan()
    p.name = "今日训练"
    p.start = m.today
    p.once = m.today
    m.library.plans = [p]
    m.selectedDate = Day.date(Day.adding(-90, to: m.today))!
    m.ensureTrainings()
    XCTAssertEqual(m.library.trainings.filter { $0.day == m.today }.count, 1)
  }

  @MainActor func testFirstReminderRequestsAuthorizationOnlyAfterSuccessfulSave() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    var requested = 0
    m.didEnableReminder = { requested += 1 }
    var t = Todo(title: "提醒测试", day: m.today)
    t.reminder = Date().addingTimeInterval(300)
    m.store.beforeReplace = { throw LifeError("模拟失败") }
    XCTAssertFalse(m.change { $0.todos.append(t) })
    XCTAssertEqual(requested, 0)
    m.store.beforeReplace = nil
    XCTAssertTrue(m.save())
    XCTAssertEqual(requested, 1)
    XCTAssertTrue(m.change { $0.todos[0].title = "修改标题" })
    XCTAssertEqual(requested, 1)
  }

  @MainActor func testUndoWriteFailureConsumesActionAndRetainsRestoredRecord() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    let todo = Todo(title: "撤销失败保留", day: m.today)
    XCTAssertTrue(m.change { $0.todos = [todo] })
    m.delete({ $0.todos.removeAll() }, undo: { $0.todos.append(todo) })
    m.store.beforeReplace = { throw LifeError("模拟磁盘失败") }
    m.undo()
    XCTAssertEqual(m.library.todos, [todo])
    XCTAssertFalse(m.undoAvailable)
    XCTAssertTrue(m.dirty)
    m.undo()
    XCTAssertEqual(m.library.todos, [todo])
    m.store.beforeReplace = nil
    XCTAssertTrue(m.save())
    XCTAssertEqual(try m.store.load().todos, [todo])
  }
  @MainActor func testReminderRoutesToExactDateAndRejectsCompletedOrDeletedItem() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let m = AppModel(directory: dir)
    m.library.autoBackup = false
    var todo = Todo(title: "通知目标", day: Day.adding(1, to: m.today))
    todo.reminder = Date().addingTimeInterval(3600)
    m.library.todos = [todo]
    let id = "life.todo." + todo.id.uuidString
    m.openReminder(id)
    XCTAssertEqual(m.page, "今日计划")
    XCTAssertEqual(m.day, todo.day)
    XCTAssertEqual(m.focusedReminderID, id)
    m.library.todos[0].done = true
    m.openReminder(id)
    XCTAssertNil(m.focusedReminderID)
    XCTAssertEqual(m.error, "对应事项已完成或已删除。")
    m.library.todos = []
    m.openReminder(id)
    XCTAssertNil(m.focusedReminderID)
    XCTAssertNotNil(m.error)
    var plan = TrainingPlan()
    plan.name = "训练通知"
    plan.start = m.today
    plan.once = m.today
    plan.reminderMinutes = 600
    m.library.plans = [plan]
    m.library.materialize(from: m.today, through: m.today)
    let trainingID = "life.training." + m.library.trainings[0].id
    m.openReminder(trainingID)
    XCTAssertEqual(m.page, "健身计划")
    XCTAssertEqual(m.day, m.today)
    XCTAssertEqual(m.focusedReminderID, trainingID)
    XCTAssertNil(m.error)
  }
}
