import XCTest

@testable import LifeCore

final class TrainingTests: XCTestCase {
  func fixture() -> Library {
    var l = Library()
    var p = TrainingPlan()
    p.name = "腿部"
    p.start = "2026-09-01"
    p.weekdays = [1, 2, 3, 4, 5, 6, 7]
    var e = Exercise()
    e.name = "深蹲"
    p.exercises = [e]
    l.plans = [p]
    return l
  }
  func testRepeatedGenerationAndReloadAreUnique() throws {
    var l = fixture()
    l.materialize(from: "2026-09-28", through: "2026-10-04")
    l = try LibraryStore.decode(LibraryStore.encode(l))
    l.materialize(from: "2026-09-28", through: "2026-10-04")
    XCTAssertEqual(l.trainings.count, 7)
    XCTAssertEqual(Set(l.trainings.map(\.id)).count, 7)
  }
  func testDirectCompleteDoesNotInventActuals() throws {
    var l = fixture()
    l.materialize(from: "2026-09-29", through: "2026-09-29")
    try l.setTrainingStatus(l.trainings[0].id, "已完成")
    XCTAssertTrue(l.trainings[0].exercises[0].sets.isEmpty)
    XCTAssertNil(l.trainings[0].exercises[0].actualMinutes)
    try l.setTrainingStatus(l.trainings[0].id, "已跳过")
    XCTAssertEqual(l.trainings[0].status, "已跳过")
  }
  func testFutureEditsPreserveHistoryInProgressAndOverride() throws {
    var l = fixture()
    l.materialize(from: "2026-09-28", through: "2026-10-02")
    l.trainings[1].status = "已完成"
    l.trainings[2].status = "进行中"
    l.trainings[3].overridden = true
    var p = l.plans[0]
    p.name = "新版"
    try l.updatePlan(p, from: "2026-09-29")
    for day in ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01"] {
      XCTAssertEqual(l.trainings.first { $0.day == day }?.name, "腿部")
    }
    XCTAssertEqual(l.trainings.first { $0.day == "2026-10-02" }?.name, "新版")
  }
  func testSingleOverrideAndCancellationProtectRecords() throws {
    var l = fixture()
    l.materialize(from: "2026-09-29", through: "2026-10-02")
    var t = l.trainings[0]
    t.name = "只改今天"
    var s = SetRecord()
    s.reps = 8
    s.weight = 25
    t.exercises[0].sets = [s]
    try l.updateTraining(t)
    l.cancelPlan(l.plans[0].id, from: "2026-09-29")
    XCTAssertEqual(l.trainings.count, 1)
    let loaded = try LibraryStore.decode(LibraryStore.encode(l))
    XCTAssertEqual(loaded.trainings[0].exercises[0].sets[0].reps, 8)
    XCTAssertEqual(loaded.trainings[0].name, "只改今天")
  }
  func testOnceAndDifferentPlansSameDay() {
    var l = fixture()
    var p = l.plans[0]
    p.id = UUID()
    p.once = "2026-09-29"
    l.plans.append(p)
    l.materialize(from: "2026-09-29", through: "2026-09-30")
    XCTAssertEqual(l.trainings.filter { $0.day == "2026-09-29" }.count, 2)
    XCTAssertEqual(l.trainings.filter { $0.day == "2026-09-30" }.count, 1)
  }
}
