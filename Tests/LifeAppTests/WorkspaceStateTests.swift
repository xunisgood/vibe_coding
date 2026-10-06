import AppKit
import LifeCore
import XCTest

@testable import LifeApp

final class WorkspaceStateTests: XCTestCase {
  @MainActor func testPreferencesRestoreWithoutChangingBusinessData() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    var model: AppModel? = AppModel(directory: dir)
    let note = Note()
    model!.library.autoBackup = false
    XCTAssertTrue(model!.change { $0.notes.append(note) })
    let before = try Data(contentsOf: model!.store.file)
    model!.selectedNoteID = note.id
    model!.page = "笔记"
    model!.sidebarVisible = false
    model!.sidebarWidth = 245
    model!.selectedDate = Day.date("2026-01-02")!
    model!.recordWindowFrame(NSRect(x: 90, y: 120, width: 1200, height: 800))
    XCTAssertEqual(try Data(contentsOf: model!.store.file), before)
    model = nil
    let restored = AppModel(directory: dir)
    XCTAssertFalse(restored.locked)
    XCTAssertEqual(restored.page, "笔记")
    XCTAssertEqual(restored.selectedNoteID, note.id)
    XCTAssertFalse(restored.sidebarVisible)
    XCTAssertEqual(restored.sidebarWidth, 245)
    XCTAssertEqual(restored.day, "2026-01-02")
    XCTAssertEqual(NSRectFromString(restored.windowFrame!).width, 1200)
  }
  @MainActor func testInvalidPreferencesFallbackWithoutLockingData() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("broken".utf8).write(to: dir.appendingPathComponent("workspace.json"))
    let model = AppModel(directory: dir)
    XCTAssertFalse(model.locked)
    XCTAssertNotNil(model.workspaceWarning)
    XCTAssertEqual(model.page, "首页总览")
    XCTAssertTrue(model.change { $0.todos.append(Todo(title: "Still works", day: model.today)) })
    var state = WorkspaceState()
    state.page = "Missing"
    state.noteID = UUID()
    state.projectID = UUID()
    state.sidebarWidth = 900
    state.selectedDay = "invalid"
    let safe = state.validated(in: model.library)
    XCTAssertEqual(safe.page, "首页总览")
    XCTAssertNil(safe.noteID)
    XCTAssertNil(safe.projectID)
    XCTAssertEqual(safe.sidebarWidth, 260)
    XCTAssertTrue(safe.followsToday)
  }
  func testDisconnectedDisplayFrameMovesBackOntoScreen() throws {
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let frame = try XCTUnwrap(
      WorkspaceState.fittedFrame(
        NSRect(x: 4000, y: -2000, width: 1800, height: 1000), screens: [screen]))
    XCTAssertTrue(screen.contains(frame))
    XCTAssertNil(WorkspaceState.fittedFrame(.zero, screens: [screen]))
  }
}
