import XCTest

@testable import LifeCore

final class DailyTests: XCTestCase {
  func testMovePreservesIDAndTime() throws {
    var l = Library()
    var t = Todo(title: "t", day: "2026-09-28")
    t.reminder = Calendar.current.date(
      bySettingHour: 18, minute: 30, second: 0, of: Day.date(t.day)!)
    l.todos = [t]
    try l.moveTodo(t.id, to: "2026-09-29")
    XCTAssertEqual(l.todos.count, 1)
    XCTAssertEqual(l.todos[0].id, t.id)
    XCTAssertEqual(Day.key(l.todos[0].reminder!), "2026-09-29")
    XCTAssertEqual(Calendar.current.component(.hour, from: l.todos[0].reminder!), 18)
  }
  func testMemoConversionIdempotentAcrossSerialization() throws {
    var l = Library()
    let m = Memo("read")
    l.memos = [m]
    let id = try l.convertMemo(m.id, to: "todo", day: "2026-09-29")
    l = try LibraryStore.decode(LibraryStore.encode(l))
    XCTAssertEqual(try l.convertMemo(m.id, to: "todo", day: "2026-09-29"), id)
    XCTAssertEqual(l.todos.count, 1)
  }
  func testNoteConversionAndBodySearch() throws {
    var l = Library()
    let m = Memo("记住这个学习方法")
    l.memos = [m]
    let id = try l.convertMemo(m.id, to: "note", day: "2026-09-29")
    l.notes[0].title = "标题"
    XCTAssertEqual(l.matchingNotes("学习").first?.id, id)
    XCTAssertTrue(l.matchingNotes("不存在").isEmpty)
  }
  func testCompletionAndHistoricalDaySurviveReload() throws {
    var l = Library()
    var t = Todo(title: "t", day: "2026-01-01")
    t.done = true
    l.todos = [t]
    let restored = try LibraryStore.decode(LibraryStore.encode(l))
    XCTAssertTrue(restored.todos[0].done)
    XCTAssertEqual(restored.todos[0].day, "2026-01-01")
  }
}
