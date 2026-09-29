import XCTest
@testable import LifeCore
final class BackupTests: XCTestCase {
    var dir: URL!; var store: LibraryStore!; var service: BackupService!
    override func setUpWithError() throws { dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); store = LibraryStore(directory: dir); service = BackupService(store: store) }
    override func tearDownWithError() throws { if FileManager.default.fileExists(atPath: dir.path) { try FileManager.default.removeItem(at: dir) } }
    func testRestoreAllCollectionsAndRelations() throws {
        var original = Library(); original.todos = [Todo(title: "task", day: "2026-09-29")]; original.notes = [Note()]; original.memos = [Memo("memo")]; original.projects = [Project("project")]
        var p = TrainingPlan(); p.name = "训练"; p.once = p.start; original.plans = [p]; original.trainings = [Training(plan: p, day: p.start)]
        original.meals = [Meal(day: p.start, slot: "早餐")]; original.games = [Game(day: p.start, name: "game", minutes: 20)]
        let b = try service.create(original); var current = Library(); current.todos = [Todo(title: "new", day: p.start)]; try store.save(current)
        XCTAssertEqual(try service.restore(b, current: current), original); XCTAssertEqual(try store.load(), original)
        let files = try FileManager.default.contentsOfDirectory(at: service.directory(for: current), includingPropertiesForKeys: nil)
        let safety = try XCTUnwrap(files.first { $0.pathExtension == "original" }); XCTAssertEqual(try LibraryStore.decode(Data(contentsOf: safety)), current)
    }
    func testChecksumAndFutureVersionRefused() throws {
        try store.save(Library()); let url = try service.create(Library()); var b = try service.inspect(url); b.payload.append(0)
        try JSONEncoder().encode(b).write(to: url); XCTAssertThrowsError(try service.restore(url, current: Library())); XCTAssertEqual(try store.load(), Library())
        b = BackupEnvelope(data: try LibraryStore.encode(Library()), created: Date()); b.format = 9
        try JSONEncoder().encode(b).write(to: url); XCTAssertThrowsError(try service.restore(url, current: Library()))
    }
    func testRestorePreBackupFailureLeavesCurrent() throws {
        let b = try service.create(Library()); var current = Library(); current.todos = [Todo(title: "keep", day: "2026-09-29")]; try store.save(current)
        let bad = dir.appendingPathComponent("not-directory"); try Data().write(to: bad); current.backupPath = bad.path
        XCTAssertThrowsError(try service.restore(b, current: current)); XCTAssertEqual(try store.load().todos, current.todos)
    }
    func testRestoreWriteFailureLeavesCurrent() throws {
        let b = try service.create(Library()); var current = Library(); current.todos = [Todo(title: "keep", day: "2026-09-29")]; try store.save(current)
        store.beforeReplace = { throw LifeError("failure") }; XCTAssertThrowsError(try service.restore(b, current: current)); XCTAssertEqual(try store.load(), current)
    }
    func testDailyRetentionDoesNotDeleteManual() throws {
        let l = Library(), manual = try service.create(Library())
        for i in 0..<10 { try service.automatic(l, now: Day.date(Day.adding(i, to: "2026-09-01"))!) }
        let files = try FileManager.default.contentsOfDirectory(atPath: service.directory(for: l).path)
        XCTAssertEqual(files.filter { $0.hasPrefix("daily-") }.count, 7); XCTAssertTrue(FileManager.default.fileExists(atPath: manual.path))
        try service.automatic(l, now: Day.date("2026-09-10")!); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: service.directory(for: l).path).count, 8)
    }
    func testCorruptOriginalPreservedDuringRecovery() throws {
        let backup = try service.create(Library()); let damaged = Data("damaged".utf8); try damaged.write(to: store.file)
        _ = try service.restore(backup, current: Library())
        let files = try FileManager.default.contentsOfDirectory(at: service.directory(for: Library()), includingPropertiesForKeys: nil)
        let safety = try XCTUnwrap(files.first { $0.pathExtension == "original" }); XCTAssertEqual(try Data(contentsOf: safety), damaged)
    }
}
