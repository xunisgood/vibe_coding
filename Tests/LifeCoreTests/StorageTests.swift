import XCTest

@testable import LifeCore

final class StorageTests: XCTestCase {
  var dir: URL!
  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }
  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.removeItem(at: dir)
    }
  }
  func testFreshStoreIsEmptyAndRoundTripsAcrossInstances() throws {
    let s = LibraryStore(directory: dir)
    XCTAssertEqual(try s.load(), Library())
    var l = Library()
    l.todos.append(Todo(title: "测试任务", day: "2026-09-29"))
    try s.save(l)
    XCTAssertEqual(try LibraryStore(directory: dir).load(), l)
  }
  func testInterruptedWritePreservesLastSavedFile() throws {
    let s = LibraryStore(directory: dir)
    var l = Library()
    try s.save(l)
    s.beforeReplace = { throw LifeError("模拟写入中断") }
    l.todos.append(Todo(title: "未成功保存", day: "2026-09-29"))
    XCTAssertThrowsError(try s.save(l))
    XCTAssertEqual(try s.load(), Library())
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["library.json"])
  }
  func testCorruptLoadDoesNotOverwriteOriginal() throws {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let s = LibraryStore(directory: dir)
    let bytes = Data("broken".utf8)
    try bytes.write(to: s.file)
    XCTAssertThrowsError(try s.load())
    XCTAssertEqual(try Data(contentsOf: s.file), bytes)
  }
  func testInvalidAndFutureVersionRejectedBeforeWrite() throws {
    let s = LibraryStore(directory: dir)
    try s.save(Library())
    var l = Library()
    l.version = 42
    XCTAssertThrowsError(try s.save(l))
    l.version = 1
    l.games.append(Game(day: "bad", name: "", minutes: -1))
    XCTAssertThrowsError(try s.save(l))
    XCTAssertEqual(try s.load(), Library())
  }
  func testUnwritablePathFailsWithoutReplacingParent() throws {
    try Data("parent file".utf8).write(to: dir)
    XCTAssertThrowsError(try LibraryStore(directory: dir).save(Library()))
    XCTAssertEqual(try Data(contentsOf: dir), Data("parent file".utf8))
  }
  func testDuplicateAndOrphanTrainingRejected() throws {
    var l = Library()
    let t = Todo(title: "x", day: "2026-09-29")
    l.todos = [t, t]
    XCTAssertThrowsError(try l.validate())
    l.todos = []
    l.trainings = [Training(plan: TrainingPlan(), day: "2026-09-29")]
    XCTAssertThrowsError(try l.validate())
  }
  func testExclusiveLeasePreventsSecondWriterAndReleases() throws {
    var first: DataLease? = try DataLease(directory: dir)
    XCTAssertNotNil(first)
    XCTAssertThrowsError(try DataLease(directory: dir))
    first = nil
    XCTAssertNoThrow(try DataLease(directory: dir))
  }

}
