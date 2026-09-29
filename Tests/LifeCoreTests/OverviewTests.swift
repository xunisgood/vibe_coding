import XCTest

@testable import LifeCore

final class OverviewTests: XCTestCase {
  func testSummaryReflectsSingleSourceAndDates() throws {
    let day = "2026-09-29"
    var l = Library()
    l.todos = [Todo(title: "today", day: day), Todo(title: "yesterday", day: "2026-09-28")]
    var p = TrainingPlan()
    p.name = "train"
    p.start = day
    p.once = day
    l.plans = [p]
    l.materialize(from: day, through: day)
    l.games = [
      Game(day: day, name: "a", minutes: 45), Game(day: "2026-09-28", name: "b", minutes: 50),
    ]
    XCTAssertEqual(l.overview(day: day).todoCount, 1)
    XCTAssertEqual(l.overview(day: day).gameMinutes, 45)
    l.todos[0].done = true
    try l.setTrainingStatus(l.trainings[0].id, "已完成")
    XCTAssertEqual(l.overview(day: day).completedTrainings, 1)
    XCTAssertEqual(l.overview(day: day).todoCount, 0)
    XCTAssertEqual(l.overview(day: day).completedTodos, 1)
    l.games.removeFirst()
    XCTAssertEqual(l.overview(day: day).gameMinutes, 0)
  }
  func testArchivedProjectNotInHomeAndEmptyStatesAreZero() {
    var l = Library()
    XCTAssertEqual(l.overview(day: "2026-09-29").trainingCount, 0)
    XCTAssertNil(l.overview(day: "2026-09-29").latestProjectID)
    var a = Project("archived")
    a.archived = true
    let b = Project("active")
    l.projects = [a, b]
    XCTAssertEqual(l.overview(day: "2026-09-29").latestProjectID, b.id)
  }
}
