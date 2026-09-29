import XCTest

@testable import LifeCore

final class ReminderTests: XCTestCase {
  func testCompleteSkipAndDeleteCancelFuture() throws {
    let now = Date()
    var l = Library()
    var t = Todo(title: "task", day: Day.key(now))
    t.reminder = now.addingTimeInterval(30)
    l.todos = [t]
    var p = TrainingPlan()
    p.name = "train"
    p.once = p.start
    l.plans = [p]
    var tr = Training(plan: p, day: p.start)
    tr.reminder = now.addingTimeInterval(40)
    l.trainings = [tr]
    XCTAssertEqual(l.futureReminders(now: now).count, 2)
    l.todos[0].done = true
    try l.setTrainingStatus(tr.id, "已跳过")
    XCTAssertTrue(l.futureReminders(now: now).isEmpty)
    l.todos[0].done = false
    l.todos = []
    XCTAssertTrue(l.futureReminders(now: now).isEmpty)
  }
  func testRescheduleKeepsNotificationIDChangesAckKey() {
    let now = Date()
    var l = Library()
    var t = Todo(title: "task", day: Day.key(now))
    t.reminder = now.addingTimeInterval(-30)
    l.todos = [t]
    let old = l.reminders()[0]
    l.acknowledge([old])
    XCTAssertTrue(l.missedReminders(now: now).isEmpty)
    l.todos[0].reminder = now.addingTimeInterval(-10)
    XCTAssertEqual(l.reminders()[0].id, old.id)
    XCTAssertEqual(l.missedReminders(now: now).count, 1)
  }
  func testMissedAcknowledgementSurvivesRestoreSerialization() throws {
    let now = Date()
    var l = Library()
    var t = Todo(title: "task", day: Day.key(now))
    t.reminder = now.addingTimeInterval(-1)
    l.todos = [t]
    XCTAssertEqual(l.missedReminders(now: now).count, 1)
    l.acknowledge(l.missedReminders(now: now))
    l = try LibraryStore.decode(LibraryStore.encode(l))
    XCTAssertTrue(l.missedReminders(now: now).isEmpty)
  }
  func testRestorePlannerHasNoStaleIdentifiers() {
    let now = Date()
    var l = Library()
    for i in 1...3 {
      var t = Todo(title: "\(i)", day: Day.key(now))
      t.reminder = now.addingTimeInterval(Double(i * 20))
      l.todos.append(t)
    }
    let before = Set(l.reminders().map(\.id))
    l.todos.removeLast()
    let after = Set(l.futureReminders(now: now).map(\.id))
    XCTAssertEqual(before.subtracting(after).count, 1)
  }
}
