import LifeCore
import XCTest

@testable import LifeApp

final class TodoDraftTests: XCTestCase {
  @MainActor func testDraftPreservesCompletionAndFailsForDeletedRecord() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let model = AppModel(directory: dir)
    model.library.autoBackup = false
    let todo = Todo(title: "Original", day: model.today)
    XCTAssertTrue(model.change { $0.todos.append(todo) })
    let draft = TodoDraft()
    draft.load(todo)
    XCTAssertFalse(draft.dirty)
    draft.value.title = "Changed"
    XCTAssertTrue(draft.dirty)
    XCTAssertEqual(model.library.todos[0].title, "Original")
    XCTAssertTrue(model.change { $0.todos[0].done = true })
    XCTAssertTrue(draft.save(model))
    XCTAssertTrue(model.library.todos[0].done)
    XCTAssertEqual(try model.store.load().todos[0].title, "Changed")
    XCTAssertTrue(model.change { $0.todos.removeAll() })
    draft.value.title = "Should not reappear"
    XCTAssertFalse(draft.save(model))
    XCTAssertTrue(model.library.todos.isEmpty)
  }
}
