import Foundation

public struct Todo: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var title: String
  public var day: String
  public var detail = ""
  public var done = false
  public var reminder: Date?
  public init(title: String, day: String) {
    self.title = title
    self.day = day
  }
}
public struct Note: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var title = "新笔记"
  public var body = ""
  public var updated = Date()
  public init() {}
}
public struct Memo: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var body: String
  public var targetID: UUID?
  public var targetKind: String?
  public init(_ body: String) { self.body = body }
}
public struct DevEntry: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var kind = "任务"
  public var title = ""
  public var body = ""
  public var status = "待处理"
  public var day = Day.key(Date())
  public var updated = Date()
  public init() {}
}
public struct Project: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var name: String
  public var detail = ""
  public var archived = false
  public var updated = Date()
  public var entries: [DevEntry] = []
  public init(_ name: String) { self.name = name }
}
public struct SetRecord: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var reps: Int?
  public var weight: Double?
  public var done = false
  public init() {}
}
public struct Exercise: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var name = ""
  public var kind = "力量"
  public var plannedSets = 3
  public var plannedReps = 10
  public var plannedWeight = 0.0
  public var plannedMinutes = 20
  public var sets: [SetRecord] = []
  public var actualMinutes: Int?
  public init() {}
  public var hasActual: Bool {
    actualMinutes != nil || sets.contains { $0.done || $0.reps != nil || $0.weight != nil }
  }
  public func fresh() -> Exercise {
    var e = self
    e.sets = []
    e.actualMinutes = nil
    return e
  }
}
public struct TrainingPlan: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var name = ""
  public var start = Day.key(Date())
  public var weekdays: [Int] = []
  public var revisionStart: String?
  public var once: String?
  public var end: String?
  public var reminderMinutes: Int?
  public var exercises: [Exercise] = []
  public init() {}
  public func matches(_ day: String) -> Bool {
    guard day >= start, revisionStart == nil || day >= revisionStart!, end == nil || day <= end!,
      let date = Day.date(day)
    else { return false }
    return once.map { $0 == day }
      ?? weekdays.contains(Calendar.current.component(.weekday, from: date))
  }
}
public struct Training: Codable, Identifiable, Equatable {
  public var id: String
  public var planID: UUID
  public var day: String
  public var name: String
  public var status = "未开始"
  public var exercises: [Exercise]
  public var overridden = false
  public var reminder: Date?
  public init(plan: TrainingPlan, day: String) {
    id = plan.id.uuidString + ":" + day
    planID = plan.id
    self.day = day
    name = plan.name
    exercises = plan.exercises.map { $0.fresh() }
    if let m = plan.reminderMinutes, let d = Day.date(day) {
      reminder = Calendar.current.date(byAdding: .minute, value: m, to: d)
    }
  }
  public var protected: Bool {
    overridden || status != "未开始" || exercises.contains { $0.hasActual }
  }
}
public struct Meal: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var day: String
  public var slot: String
  public var planned = ""
  public var actual = ""
  public var calories: Double?
  public var protein: Double?
  public init(day: String, slot: String) {
    self.day = day
    self.slot = slot
  }
}
public struct Game: Codable, Identifiable, Equatable {
  public var id = UUID()
  public var day: String
  public var name: String
  public var minutes: Int
  public var note = ""
  public init(day: String, name: String, minutes: Int) {
    self.day = day
    self.name = name
    self.minutes = minutes
  }
}
public struct Library: Codable, Equatable {
  public var version = 1
  public var todos: [Todo] = []
  public var notes: [Note] = []
  public var memos: [Memo] = []
  public var projects: [Project] = []
  public var plans: [TrainingPlan] = []
  public var trainings: [Training] = []
  public var meals: [Meal] = []
  public var games: [Game] = []
  public var acknowledgedReminders: Set<String> = []
  public var autoBackup = true
  public var backupPath: String?
  public init() {}
}
public struct LifeError: LocalizedError {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}
extension Library {
  public func validate() throws {
    guard version == 1 else { throw LifeError("不支持的数据版本：\(version)") }
    func require(_ value: Bool, _ message: String) throws { if !value { throw LifeError(message) } }
    func unique<T: Hashable>(_ a: [T]) -> Bool { Set(a).count == a.count }
    func text(_ s: String) -> Bool { !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func valid(_ d: String) -> Bool { Day.date(d) != nil }
    func nonnegative(_ n: Double?) -> Bool { n == nil || (n!.isFinite && n! >= 0) }
    try require(
      unique(todos.map(\.id)) && unique(notes.map(\.id)) && unique(memos.map(\.id))
        && unique(projects.map(\.id)) && unique(plans.map(\.id)) && unique(trainings.map(\.id))
        && unique(meals.map(\.id)) && unique(games.map(\.id)), "数据包含重复标识")
    for t in todos { try require(text(t.title) && valid(t.day), "待办名称或日期无效") }
    for p in projects {
      try require(text(p.name) && unique(p.entries.map(\.id)), "项目名称或条目标识无效")
      for e in p.entries {
        try require(
          text(e.title) && valid(e.day) && ["任务", "问题", "笔记", "进展"].contains(e.kind)
            && ["待处理", "进行中", "已完成"].contains(e.status), "开发条目无效")
      }
    }
    func exercise(_ e: Exercise) throws {
      try require(
        text(e.name) && ["力量", "有氧"].contains(e.kind) && (1...100).contains(e.plannedSets)
          && e.plannedReps > 0 && nonnegative(e.plannedWeight) && e.plannedMinutes > 0, "动作计划无效")
      try require(
        unique(e.sets.map(\.id)) && (e.actualMinutes == nil || e.actualMinutes! >= 0), "动作实际记录无效")
      for s in e.sets {
        try require((s.reps == nil || s.reps! >= 0) && nonnegative(s.weight), "次数和重量不能为负数")
      }
    }
    for p in plans {
      try require(
        text(p.name) && valid(p.start) && (p.revisionStart == nil || valid(p.revisionStart!))
          && (p.end == nil || valid(p.end!)) && (p.once == nil || valid(p.once!))
          && p.weekdays.allSatisfy { (1...7).contains($0) }
          && (p.once != nil || !p.weekdays.isEmpty), "训练安排名称、日期或星期无效")
      try require(p.reminderMinutes == nil || (0..<1440).contains(p.reminderMinutes!), "训练提醒时间无效")
      try require(unique(p.exercises.map(\.id)), "动作标识重复")
      try p.exercises.forEach(exercise)
    }
    for t in trainings {
      try require(
        plans.contains { $0.id == t.planID } && t.id == t.planID.uuidString + ":" + t.day
          && valid(t.day) && text(t.name), "训练关联或日期无效")
      try require(
        ["未开始", "进行中", "已完成", "已跳过"].contains(t.status) && unique(t.exercises.map(\.id)), "训练状态无效")
      try t.exercises.forEach(exercise)
    }
    try require(unique(meals.map { $0.day + ":" + $0.slot }), "餐次重复")
    for m in meals {
      try require(
        valid(m.day) && ["早餐", "午餐", "晚餐", "加餐"].contains(m.slot) && nonnegative(m.calories)
          && nonnegative(m.protein), "饮食日期、餐次或营养值无效")
    }
    for g in games { try require(valid(g.day) && text(g.name) && g.minutes > 0, "游戏名称、日期或时长无效") }
    for m in memos {
      try require(text(m.body), "备忘不能为空")
      try require(
        (m.targetID == nil) == (m.targetKind == nil)
          && (m.targetKind == nil || ["todo", "note"].contains(m.targetKind!)), "备忘转换状态无效")
    }
  }
}
