import SwiftUI
import LifeCore
struct TodosView: View {
    @ObservedObject var model: AppModel
    @State private var title = ""
    @State private var editing: Todo?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DayPicker(model: model)
            HStack {
                TextField("今天想做什么？", text: $title).onSubmit(add).accessibilityIdentifier("todo-input")
                Button("添加", action: add).buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Panel(title: "待完成") {
                let items = model.library.todos.filter { $0.day == model.day && !$0.done }
                if items.isEmpty { Text("这一天暂无待办，添加一件想做的事。").foregroundStyle(.secondary) }
                ForEach(items) { row($0) }
            }
            if model.library.todos.contains(where: { $0.day == model.day && $0.done }) {
                DisclosureGroup("已完成") {
                    ForEach(model.library.todos.filter { $0.day == model.day && $0.done }) { row($0) }
                }
            }
            if model.day == model.today {
                let earlier = model.library.todos.filter { $0.day < model.today && !$0.done }
                if !earlier.isEmpty {
                    DisclosureGroup("此前未完成 · \(earlier.count) 项") {
                        ForEach(earlier) { t in
                            HStack {
                                Text(t.title)
                                Text(t.day).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("移到今天") { model.change { try $0.moveTodo(t.id, to: model.today) } }
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }
        }.sheet(item: $editing) { todo in TodoEditor(model: model, original: todo) }
    }
    func add() { let clean = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }; if model.change({ $0.todos.append(Todo(title: clean, day: model.day)) }) { title = "" } }
    func row(_ t: Todo) -> some View {
        HStack(alignment: .top) {
            Toggle("完成", isOn: Binding(get: { t.done }, set: { v in model.change { l in if let i = l.todos.firstIndex(where: { $0.id == t.id }) { l.todos[i].done = v } } })).labelsHidden()
            VStack(alignment: .leading) { Text(t.title).strikethrough(t.done); if let r = t.reminder { Text("提醒 " + r.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary) } }
            Spacer(); Button("详情") { editing = t }; Button("删除") { model.delete({ $0.todos.removeAll { $0.id == t.id } }, undo: { $0.todos.append(t) }) }
        }.padding(.vertical, 8)
    }
}
struct TodoEditor: View {
    @ObservedObject var model: AppModel; @Environment(\.dismiss) var dismiss
    @State var value: Todo; @State var date: Date; @State var reminder: Date; @State var hasReminder: Bool
    init(model: AppModel, original: Todo) { self.model = model; _value = State(initialValue: original); _date = State(initialValue: Day.date(original.day)!); _reminder = State(initialValue: original.reminder ?? Date()); _hasReminder = State(initialValue: original.reminder != nil) }
    var body: some View { VStack(alignment: .leading, spacing: 16) {
        Text("待办详情").font(.title2); TextField("名称（必填）", text: $value.title)
        DatePicker("所属日期", selection: $date, displayedComponents: .date)
        Text("说明"); TextEditor(text: $value.detail).frame(height: 120).border(.quaternary)
        Toggle("提醒我", isOn: $hasReminder)
        if hasReminder { DatePicker("提醒时间", selection: $reminder, displayedComponents: [.hourAndMinute]) }
        HStack { Button("取消") { dismiss() }; Spacer(); Button("保存") {
            value.day = Day.key(date); value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let c = Calendar.current.dateComponents([.hour,.minute], from: reminder)
            value.reminder = hasReminder ? Calendar.current.date(bySettingHour: c.hour!, minute: c.minute!, second: 0, of: date) : nil
            if model.change({ l in if let i = l.todos.firstIndex(where: { $0.id == value.id }) { l.todos[i] = value } }) { dismiss() }
        }.buttonStyle(.borderedProminent).disabled(value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    }.padding(24).frame(width: 500) }
}
struct NotesView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""; @State private var selection: UUID?
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { TextField("搜索标题和正文", text: $query); Button("新建") { let n = Note(); if model.change({ $0.notes.insert(n, at: 0) }) { selection = n.id } } }
                ForEach(model.library.matchingNotes(query)) { n in Button { selection = n.id } label: { VStack(alignment: .leading) { Text(n.title.isEmpty ? "无标题" : n.title).font(.headline); Text(n.updated.formatted()).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(selection == n.id ? Color.accentColor.opacity(0.1) : .clear).cornerRadius(8) }.buttonStyle(.plain) }
                if model.library.matchingNotes(query).isEmpty { Text(query.isEmpty ? "暂无笔记" : "没有匹配的笔记").foregroundStyle(.secondary) }
            }.frame(width: 245)
            Divider()
            if let id = selection, let n = model.library.notes.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("标题", text: noteBinding(id, \.title)).font(.title2)
                    TextEditor(text: noteBinding(id, \.body)).frame(minHeight: 350).padding(8).background(.background).cornerRadius(8)
                    HStack { Text("自动保存").font(.caption).foregroundStyle(.secondary); Spacer(); Button("删除笔记") { model.delete({ $0.notes.removeAll { $0.id == id } }, undo: { $0.notes.append(n) }); selection = nil } }
                }
            } else { ContentUnavailableView("记录一个想法", systemImage: "note.text", description: Text("新建笔记或选择已有笔记")) }
        }.onAppear { if selection == nil { selection = model.library.notes.first?.id } }
    }
    func noteBinding(_ id: UUID, _ path: WritableKeyPath<Note,String>) -> Binding<String> {
        Binding(get: { model.library.notes.first { $0.id == id }?[keyPath: path] ?? "" }, set: { value in model.change { l in if let i = l.notes.firstIndex(where: { $0.id == id }) { l.notes[i][keyPath: path] = value; l.notes[i].updated = Date() } } })
    }
}
struct MemosView: View {
    @ObservedObject var model: AppModel; @State private var text = ""; @State private var editID: UUID?
    var body: some View {
        Panel(title: "快速备忘") {
            TextField("随手记下一个想法…", text: $text, axis: .vertical).lineLimit(2...5)
            HStack { Button(editID == nil ? "保存备忘" : "保存修改") {
                let v = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !v.isEmpty else { return }
                if model.change({ l in if let id = editID, let i = l.memos.firstIndex(where: { $0.id == id }) { l.memos[i].body = v } else { l.memos.insert(Memo(v), at: 0) } }) { text = ""; editID = nil }
            }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty); if editID != nil { Button("取消编辑") { text = ""; editID = nil } } }
            ForEach(model.library.memos.filter { $0.targetID == nil }) { m in
                VStack(alignment: .leading) { Text(m.body); HStack {
                    Button("转为待办") { model.change { _ = try $0.convertMemo(m.id, to: "todo", day: model.today) } }
                    Button("转为笔记") { if model.change({ _ = try $0.convertMemo(m.id, to: "note", day: model.today) }) { model.page = "笔记" } }
                    Button("编辑") { text = m.body; editID = m.id }
                    Button("删除") { model.delete({ $0.memos.removeAll { $0.id == m.id } }, undo: { $0.memos.append(m) }) }
                }.font(.caption) }.padding(.vertical, 6)
            }
        }
    }
}
