import Foundation

public struct NutritionSummary: Equatable {
  public var calories: Double
  public var protein: Double
  public var partial: Bool
  public var recordedMeals: Int
}
extension Library {
  public func nutrition(on day: String) -> NutritionSummary {
    let actual = meals.filter {
      $0.day == day && !$0.actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return NutritionSummary(
      calories: actual.compactMap(\.calories).reduce(0, +),
      protein: actual.compactMap(\.protein).reduce(0, +),
      partial: !Set(["早餐", "午餐", "晚餐"]).isSubset(of: Set(actual.map(\.slot)))
        || actual.contains { $0.calories == nil || $0.protein == nil },
      recordedMeals: actual.count)
  }
  public mutating func eatAsPlanned(_ id: UUID) throws {
    guard let i = meals.firstIndex(where: { $0.id == id }),
      !meals[i].planned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw LifeError("请先填写饮食计划") }
    meals[i].actual = meals[i].planned
  }
  public func gameMinutes(on day: String) -> Int {
    games.filter { $0.day == day }.reduce(0) { $0 + $1.minutes }
  }
  public mutating func archiveProject(_ id: UUID, archived: Bool) throws {
    guard let i = projects.firstIndex(where: { $0.id == id }) else { throw LifeError("项目不存在") }
    projects[i].archived = archived
    projects[i].updated = Date()
  }
  public mutating func saveEntry(_ entry: DevEntry, projectID: UUID) throws {
    guard let i = projects.firstIndex(where: { $0.id == projectID }) else {
      throw LifeError("项目不存在")
    }
    var e = entry
    e.updated = Date()
    if let j = projects[i].entries.firstIndex(where: { $0.id == e.id }) {
      projects[i].entries[j] = e
    } else {
      projects[i].entries.append(e)
    }
    projects[i].updated = Date()
  }
}
public enum GameDuration {
  public static func minutes(hours: Int, minutes: Int) throws -> Int {
    guard (0...100000).contains(hours), (0...59).contains(minutes), hours * 60 + minutes > 0 else {
      throw LifeError("请输入有效时长：小时为非负整数，分钟为 0–59，总时长大于零")
    }
    return hours * 60 + minutes
  }
}
