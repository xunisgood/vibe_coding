import Foundation

extension Library {
  public mutating func materialize(from start: String, through end: String) {
    guard Day.date(start) != nil, Day.date(end) != nil, start <= end else { return }
    var existing = Set(trainings.map(\.id))
    var day = start
    while day <= end {
      for plan in plans where plan.matches(day) {
        let t = Training(plan: plan, day: day)
        if existing.insert(t.id).inserted { trainings.append(t) }
      }
      day = Day.adding(1, to: day)
    }
    trainings.sort { $0.day == $1.day ? $0.id < $1.id : $0.day < $1.day }
  }
  public mutating func updatePlan(_ plan: TrainingPlan, from day: String) throws {
    guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { throw LifeError("安排不存在") }
    // Freeze the old rule's past before activating its replacement.
    materialize(from: plans[i].start, through: Day.adding(-1, to: day))
    var revised = plan
    revised.revisionStart = day
    plans[i] = revised
    trainings = trainings.compactMap { t in
      guard t.planID == plan.id, t.day >= day, !t.protected else { return t }
      return revised.matches(t.day) ? Training(plan: revised, day: t.day) : nil
    }
    materialize(from: day, through: Day.adding(45, to: day))
  }
  public mutating func cancelPlan(_ id: UUID, from day: String) {
    guard let i = plans.firstIndex(where: { $0.id == id }) else { return }
    plans[i].end = Day.adding(-1, to: day)
    trainings.removeAll { $0.planID == id && $0.day >= day && !$0.protected }
  }
  public mutating func setTrainingStatus(_ id: String, _ status: String) throws {
    guard let i = trainings.firstIndex(where: { $0.id == id }),
      ["未开始", "进行中", "已完成", "已跳过"].contains(status)
    else { throw LifeError("训练不存在或状态无效") }
    trainings[i].status = status
  }
  public mutating func updateTraining(_ value: Training) throws {
    guard let i = trainings.firstIndex(where: { $0.id == value.id }) else {
      throw LifeError("训练不存在")
    }
    trainings[i] = value
    trainings[i].overridden = true
  }
}
