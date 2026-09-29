import XCTest

@testable import LifeCore

final class RegressionTests: XCTestCase {
  func testFutureWeekdayChangeDoesNotInventPastSessionsOnNextLaunch() throws {
    var l = Library()
    var p = TrainingPlan()
    p.name = "原计划"
    p.start = "2026-09-01"
    p.weekdays = [3]
    l.plans = [p]
    l.materialize(from: "2026-09-01", through: "2026-10-01")
    let before = l.trainings.filter { $0.day < "2026-09-29" }
    p.weekdays = [4]
    p.name = "后续周三"
    try l.updatePlan(p, from: "2026-09-29")
    l = try LibraryStore.decode(LibraryStore.encode(l))
    l.materialize(from: "2026-09-01", through: "2026-10-15")
    XCTAssertEqual(l.trainings.filter { $0.day < "2026-09-29" }, before, "修改后续不能在历史日期生成新规则下的训练")
  }
  func testReplacingPlanExercisesDoesNotReuseActualValues() throws {
    var l = Library()
    var p = TrainingPlan()
    p.name = "计划"
    p.start = "2026-09-29"
    p.once = p.start
    var e = Exercise()
    e.name = "跑步"
    e.kind = "有氧"
    e.actualMinutes = 12
    p.exercises = [e]
    l.plans = [p]
    l.materialize(from: p.start, through: p.start)
    XCTAssertNil(l.trainings[0].exercises[0].actualMinutes)
  }
}
