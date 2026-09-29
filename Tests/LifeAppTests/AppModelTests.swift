import XCTest
import LifeCore
@testable import LifeApp
final class AppModelTests:XCTestCase {
    @MainActor func testSaveFailureRetainsEditsAndRetryPersists() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let m=AppModel(directory:dir);m.library.autoBackup=false
        m.store.beforeReplace={ throw LifeError("磁盘失败") }
        XCTAssertFalse(m.change { $0.todos.append(Todo(title:"保留输入",day:"2026-09-29")) });XCTAssertTrue(m.dirty);XCTAssertEqual(m.library.todos[0].title,"保留输入");XCTAssertTrue(m.status.contains("失败"))
        m.store.beforeReplace=nil;XCTAssertTrue(m.save());XCTAssertFalse(m.dirty);XCTAssertEqual(try m.store.load().todos,m.library.todos)
    }
    @MainActor func testCorruptStartupBlocksOrdinaryWrites() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);let file=dir.appendingPathComponent("library.json");let bad=Data("broken".utf8);try bad.write(to:file)
        let m=AppModel(directory:dir);XCTAssertTrue(m.locked);XCTAssertFalse(m.change { $0.todos.append(Todo(title:"no",day:"2026-09-29")) });XCTAssertEqual(try Data(contentsOf:file),bad)
    }
    @MainActor func testUndoDeletionKeepsUnrelatedLaterChanges() async throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:dir) }
        let m=AppModel(directory:dir);m.library.autoBackup=false;let t=Todo(title:"one",day:"2026-09-29")
        XCTAssertTrue(m.change { $0.todos=[t] });m.delete({ $0.todos=[] },undo:{ $0.todos.append(t) })
        XCTAssertTrue(m.change { $0.games.append(Game(day:"2026-09-29",name:"test",minutes:10)) });m.undo()
        XCTAssertEqual(m.library.todos,[t]);XCTAssertEqual(m.library.games.count,1);XCTAssertEqual(try m.store.load(),m.library)
    }
}
