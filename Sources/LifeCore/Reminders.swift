import Foundation

public struct Reminder: Identifiable, Equatable {
  public var id: String
  public var title: String
  public var date: Date
  public var day: String
  public var page: String
  public var acknowledgement: String { id + ":" + String(Int(date.timeIntervalSince1970)) }
}
extension Library {
  public func reminders() -> [Reminder] {
    let tasks = todos.compactMap { t -> Reminder? in
      guard !t.done, let d = t.reminder else { return nil }
      return Reminder(
        id: "life.todo." + t.id.uuidString, title: t.title, date: d, day: t.day, page: "今日计划")
    }
    let training = trainings.compactMap { t -> Reminder? in
      guard !["已完成", "已跳过"].contains(t.status), let d = t.reminder else { return nil }
      return Reminder(id: "life.training." + t.id, title: t.name, date: d, day: t.day, page: "健身计划")
    }
    return (tasks + training).sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
  }
  public func futureReminders(now: Date) -> [Reminder] { reminders().filter { $0.date > now } }
  public func missedReminders(now: Date) -> [Reminder] {
    reminders().filter { $0.date <= now && !acknowledgedReminders.contains($0.acknowledgement) }
  }
  public mutating func acknowledge(_ reminders: [Reminder]) {
    acknowledgedReminders.formUnion(reminders.map(\.acknowledgement))
  }
}
