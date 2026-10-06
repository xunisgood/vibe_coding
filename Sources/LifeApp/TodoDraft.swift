import AppKit
import LifeCore
import SwiftUI

@MainActor final class TodoDraft: ObservableObject {
  @Published var value = Todo(title: "", day: Day.key(Date()))
  @Published var date = Date()
  @Published var reminder = Date()
  @Published var hasReminder = false
  private var original: Todo?
  func load(_ todo: Todo) {
    original = todo
    value = todo
    date = Day.date(todo.day) ?? Date()
    reminder = todo.reminder ?? date
    hasReminder = todo.reminder != nil
  }
  var result: Todo {
    var t = value
    t.title = t.title.trimmingCharacters(in: .whitespacesAndNewlines)
    t.day = Day.key(date)
    let c = Calendar.current.dateComponents([.hour, .minute], from: reminder)
    t.reminder =
      hasReminder
      ? Calendar.current.date(
        bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: date) : nil
    return t
  }
  var dirty: Bool { original != nil && result != original }
  var valid: Bool { !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  @discardableResult func save(_ model: AppModel) -> Bool {
    guard valid else { return false }
    let updated = result
    let ok = model.change { library in
      guard let i = library.todos.firstIndex(where: { $0.id == updated.id }) else {
        throw LifeError("事项已被删除，请取消编辑。")
      }
      var merged = updated
      merged.done = library.todos[i].done
      library.todos[i] = merged
    }
    if ok { original = updated }
    return ok
  }
  func mayLeave(_ model: AppModel) -> Bool {
    guard dirty else { return true }
    let alert = NSAlert()
    alert.messageText = "保存待办修改？"
    alert.informativeText = "当前事项有未保存的修改。"
    alert.addButton(withTitle: "保存修改")
    alert.addButton(withTitle: "放弃修改")
    alert.addButton(withTitle: "继续编辑")
    switch alert.runModal() {
    case .alertFirstButtonReturn: return save(model)
    case .alertSecondButtonReturn: return true
    default: return false
    }
  }
}

struct TodoDraftEditor: View {
  @ObservedObject var model: AppModel
  @ObservedObject var draft: TodoDraft
  let close: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("待办详情").font(.title2)
      TextField("名称（必填）", text: $draft.value.title)
      DatePicker("所属日期", selection: $draft.date, displayedComponents: .date)
      Text("说明")
      TextEditor(text: $draft.value.detail).scrollContentBackground(.hidden)
        .frame(minHeight: 100, idealHeight: 140, maxHeight: 220).padding(10).lifeCard(radius: 12)
      Toggle("提醒我", isOn: $draft.hasReminder)
      Text("通过 Mac 系统通知提醒，首次启用会请求授权。").font(.caption).foregroundStyle(.secondary)
      if draft.hasReminder {
        DatePicker("提醒时间", selection: $draft.reminder, displayedComponents: .hourAndMinute)
      }
      HStack {
        Button("取消", action: close)
        Spacer()
        Button("保存") { if draft.save(model) { close() } }.buttonStyle(.borderedProminent).disabled(
          !draft.valid)
      }
    }.padding(20).background(LifeBackdrop())
  }
}
