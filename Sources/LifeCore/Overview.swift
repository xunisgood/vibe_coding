import Foundation

public struct Overview: Equatable {
  public var todoCount: Int
  public var completedTodos: Int
  public var trainingCount: Int
  public var completedTrainings: Int
  public var gameMinutes: Int
  public var recordedMeals: Int
  public var latestProjectID: UUID?
}
extension Library {
  public func overview(day: String) -> Overview {
    let tasks = todos.filter { $0.day == day }
    let sessions = trainings.filter { $0.day == day }
    return Overview(
      todoCount: tasks.filter { !$0.done }.count, completedTodos: tasks.filter(\.done).count,
      trainingCount: sessions.count,
      completedTrainings: sessions.filter { $0.status == "已完成" }.count,
      gameMinutes: gameMinutes(on: day), recordedMeals: nutrition(on: day).recordedMeals,
      latestProjectID: projects.filter { !$0.archived }.max { $0.updated < $1.updated }?.id)
  }
}
