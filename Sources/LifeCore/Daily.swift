import Foundation

extension Library {
  public mutating func moveTodo(_ id: UUID, to day: String) throws {
    guard Day.date(day) != nil, let i = todos.firstIndex(where: { $0.id == id }) else {
      throw LifeError("待办或日期无效")
    }
    if let reminder = todos[i].reminder {
      let time = Calendar.current.dateComponents([.hour, .minute], from: reminder)
      todos[i].reminder = Calendar.current.date(
        bySettingHour: time.hour!, minute: time.minute!, second: 0, of: Day.date(day)!)
    }
    todos[i].day = day
  }
  public mutating func convertMemo(_ id: UUID, to kind: String, day: String) throws -> UUID {
    guard let i = memos.firstIndex(where: { $0.id == id }) else { throw LifeError("备忘不存在") }
    if let target = memos[i].targetID { return target }
    let target: UUID
    if kind == "todo" {
      let t = Todo(title: memos[i].body, day: day)
      todos.append(t)
      target = t.id
    } else if kind == "note" {
      var n = Note()
      n.title = String(memos[i].body.prefix(30))
      n.body = memos[i].body
      notes.insert(n, at: 0)
      target = n.id
    } else {
      throw LifeError("无效的转换类型")
    }
    memos[i].targetID = target
    memos[i].targetKind = kind
    return target
  }
  public func matchingNotes(_ query: String) -> [Note] {
    notes.filter {
      query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
        || $0.body.localizedCaseInsensitiveContains(query)
    }.sorted { $0.updated > $1.updated }
  }
}
