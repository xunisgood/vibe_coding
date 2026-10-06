import LifeCore
import SwiftUI

struct TodosView: View {
  @ObservedObject var model: AppModel
  @State private var title = ""
  @FocusState private var inputFocused: Bool
  @FocusState private var rowFocused: UUID?
  @State private var editing: Todo?
  @State private var completedExpanded = false
  @State private var earlierExpanded = true
  @State private var availableWidth: CGFloat = 0
  @StateObject private var draft = TodoDraft()
  var wide: Bool { availableWidth >= 940 }
  func open(_ todo: Todo) {
    guard editing == nil || draft.mayLeave(model) else { return }
    draft.load(todo)
    editing = todo
  }
  func finishEditing() -> Bool {
    guard editing == nil || draft.mayLeave(model) else { return false }
    editing = nil
    return true
  }
  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      ScrollView { todoList }.frame(maxWidth: .infinity)
      if wide && editing != nil {
        TodoDraftEditor(model: model, draft: draft) { editing = nil }
          .frame(width: 320).clipShape(RoundedRectangle(cornerRadius: 14))
          .accessibilityIdentifier("todo-inspector")
      }
    }
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      availableWidth = $0
    }
    .onAppear { model.prepareToLeave = { finishEditing() } }
    .onDisappear { model.prepareToLeave = nil }
    .sheet(
      isPresented: Binding(
        get: { !wide && editing != nil }, set: { if !$0 && !wide { editing = nil } })
    ) {
      TodoDraftEditor(model: model, draft: draft) { editing = nil }.frame(width: 500)
        .interactiveDismissDisabled()
    }
  }
  private var todoList: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        TextField("今天想做什么？", text: $title).onSubmit(add).accessibilityIdentifier("todo-input")
          .focused($inputFocused)
        IconAction("添加", systemImage: "plus", action: add).buttonStyle(.borderedProminent).disabled(
          title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      Panel(title: "待完成") {
        let items = model.library.todos.filter { $0.day == model.day && !$0.done }
        if items.isEmpty { Text("这一天暂无待办，添加一件想做的事。").foregroundStyle(.secondary) }
        ForEach(items) { row($0) }
      }
      TrainingLinks(model: model, day: model.day)
      if model.library.todos.contains(where: { $0.day == model.day && $0.done }) {
        VStack(alignment: .leading, spacing: 12) {
          Button {
            completedExpanded.toggle()
          } label: {
            HStack {
              Image(systemName: completedExpanded ? "chevron.down" : "chevron.right").frame(
                width: 14)
              Text("已完成").font(.system(size: 13, weight: .semibold))
              Spacer()
              Text("\(model.library.todos.filter { $0.day == model.day && $0.done }.count)")
                .font(.caption).foregroundStyle(.secondary)
            }.padding(12).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("completed-toggle")
            .accessibilityValue(completedExpanded ? "展开" : "收起")
          if completedExpanded {
            ForEach(model.library.todos.filter { $0.day == model.day && $0.done }) { row($0) }
          }
        }.padding(8).lifeCard(radius: 16)
      }
      if model.day == model.today {
        let earlier = model.library.todos.filter { $0.day < model.today && !$0.done }
        if !earlier.isEmpty {
          DisclosureGroup("此前未完成 · \(earlier.count) 项", isExpanded: $earlierExpanded) {
            ForEach(earlier) { t in
              HStack {
                HStack {
                  Text(t.title)
                  Text(t.day).font(.caption).foregroundStyle(.secondary)
                  Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    rowFocused = t.id
                    open(t)
                  }
                  .accessibilityAction(named: Text("查看详情")) { open(t) }
                  .accessibilityIdentifier("earlier-open-\(t.title)")
                  .help("查看详情")
                IconAction("详情", systemImage: "info") { open(t) }
                Button("移到今天") { model.change { try $0.moveTodo(t.id, to: model.today) } }
              }.padding(.vertical, 6)
            }
          }
        }
      }
    }.onChange(of: model.newRequest) { _, _ in inputFocused = true }.onChange(
      of: model.focusedReminderID
    ) { _, value in
      if let value,
        let t = model.library.todos.first(where: { "life.todo." + $0.id.uuidString == value })
      {
        open(t)
      }
    }.onAppear {
      model.ensureTrainings()
      if let value = model.focusedReminderID {
        if let todo = model.library.todos.first(where: { "life.todo." + $0.id.uuidString == value })
        {
          open(todo)
        }
      }
    }.onChange(of: model.day) { _, _ in model.ensureTrainings() }
  }
  func add() {
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return }
    if model.change({ $0.todos.append(Todo(title: clean, day: model.day)) }) { title = "" }
  }
  func moveFocus(_ todo: Todo, _ delta: Int) {
    let items = model.library.todos.filter { $0.day == model.day && $0.done == todo.done }
    guard let i = items.firstIndex(where: { $0.id == todo.id }), !items.isEmpty else { return }
    rowFocused = items[min(max(i + delta, 0), items.count - 1)].id
  }
  func row(_ t: Todo) -> some View {
    HStack(alignment: .top) {
      Toggle(
        "完成",
        isOn: Binding(
          get: { t.done },
          set: { v in
            model.change { l in
              if let i = l.todos.firstIndex(where: { $0.id == t.id }) { l.todos[i].done = v }
            }
          })
      ).labelsHidden()
      VStack(alignment: .leading) {
        Text(t.title).strikethrough(t.done)
        if let r = t.reminder {
          Text("提醒 " + r.formatted(date: .omitted, time: .shortened)).font(.caption)
            .foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
          rowFocused = t.id
          open(t)
        }
        .accessibilityAction(named: Text("查看详情")) { open(t) }
        .accessibilityIdentifier("todo-open-\(t.title)")
        .help("查看详情")
        .focusable().focused($rowFocused, equals: t.id)
        .onKeyPress(.return) {
          open(t)
          return .handled
        }
        .onKeyPress(.downArrow) {
          moveFocus(t, 1)
          return .handled
        }
        .onKeyPress(.upArrow) {
          moveFocus(t, -1)
          return .handled
        }
      IconAction("详情", systemImage: "info") { open(t) }
      IconAction("删除", systemImage: "trash") {
        guard editing?.id != t.id || finishEditing() else { return }
        model.delete({ $0.todos.removeAll { $0.id == t.id } }, undo: { $0.todos.append(t) })
      }
    }.padding(.vertical, 8).contextMenu {
      Button("查看详情") { open(t) }
      Button("删除", role: .destructive) {
        guard editing?.id != t.id || finishEditing() else { return }
        model.delete({ $0.todos.removeAll { $0.id == t.id } }, undo: { $0.todos.append(t) })
      }
    }
  }
}
struct NotesView: View {
  @ObservedObject var model: AppModel
  @State private var query = ""
  @FocusState private var searchFocused: Bool
  @FocusState private var titleFocused: Bool
  @FocusState private var rowFocused: UUID?
  var matches: [Note] { model.library.matchingNotes(query) }
  var body: some View {
    HSplitView {
      noteList
      noteDetail
    }
    .onAppear {
      if !model.library.notes.contains(where: { $0.id == model.selectedNoteID }) {
        model.selectedNoteID = model.library.notes.first?.id
      }
    }
    .onChange(of: model.newRequest) { _, _ in
      let n = Note()
      if model.change({ $0.notes.insert(n, at: 0) }) {
        query = ""
        model.selectedNoteID = n.id
        titleFocused = true
      }
    }
    .onChange(of: model.searchRequest) { _, _ in searchFocused = true }
  }
  private var noteList: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
        TextField("搜索标题和正文", text: $query).focused($searchFocused)
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 6) {
          ForEach(matches) { n in
            noteRow(n)
          }
          if matches.isEmpty {
            Text(query.isEmpty ? "暂无笔记" : "没有匹配的笔记").foregroundStyle(.secondary).padding(10)
          }
        }
      }.accessibilityIdentifier("notes-list-scroll")
    }.padding(12).frame(minWidth: 220, idealWidth: 235, maxWidth: 320, maxHeight: .infinity)
      .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))

  }
  private var noteDetail: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let id = model.selectedNoteID, let n = model.library.notes.first(where: { $0.id == id }) {
        TextField("标题", text: noteBinding(id, \.title)).font(.system(size: 22, weight: .semibold))
          .focused($titleFocused)
        TextEditor(text: noteBinding(id, \.body)).font(.system(size: 14))
          .scrollContentBackground(.hidden).padding(14).lifeCard(radius: 14)
          .accessibilityIdentifier("note-body")
        HStack {
          Text(model.dirty ? "保存失败，请重试" : "自动保存").font(.caption).foregroundStyle(.secondary)
          Spacer()
          IconAction("删除笔记", systemImage: "trash") { delete(n) }
        }
      } else {
        LifeEmptyState("记录一个想法", systemImage: "note.text", description: Text("新建笔记或选择已有笔记"))
        Spacer()
      }
    }.padding(.leading, 16).frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
  }
  private func noteRow(_ n: Note) -> some View {
    Button {
      model.selectedNoteID = n.id
      rowFocused = n.id
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        Text(n.title.isEmpty ? "无标题" : n.title).font(.headline).lineLimit(2)
        Text(n.updated.formatted()).font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(model.selectedNoteID == n.id ? Color.accentColor.opacity(0.10) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }.buttonStyle(.plain).focusable().focused($rowFocused, equals: n.id)
      .onKeyPress(.downArrow) {
        move(from: n.id, by: 1)
        return .handled
      }
      .onKeyPress(.upArrow) {
        move(from: n.id, by: -1)
        return .handled
      }
      .contextMenu {
        Button("重命名") {
          model.selectedNoteID = n.id
          titleFocused = true
        }
        Button("删除笔记", role: .destructive) { delete(n) }
      }
  }
  func move(from id: UUID, by delta: Int) {
    guard let i = matches.firstIndex(where: { $0.id == id }), !matches.isEmpty else { return }
    let n = matches[min(max(i + delta, 0), matches.count - 1)]
    model.selectedNoteID = n.id
    rowFocused = n.id
  }
  func delete(_ n: Note) {
    model.delete({ $0.notes.removeAll { $0.id == n.id } }, undo: { $0.notes.append(n) })
    if model.selectedNoteID == n.id && !model.library.notes.contains(where: { $0.id == n.id }) {
      model.selectedNoteID = nil
    }
  }
  func noteBinding(_ id: UUID, _ path: WritableKeyPath<Note, String>) -> Binding<String> {
    Binding(
      get: { model.library.notes.first { $0.id == id }?[keyPath: path] ?? "" },
      set: { value in
        model.change { l in
          if let i = l.notes.firstIndex(where: { $0.id == id }) {
            l.notes[i][keyPath: path] = value
            l.notes[i].updated = Date()
          }
        }
      })
  }
}
struct MemosView: View {
  @ObservedObject var model: AppModel
  @State private var text = ""
  @State private var editID: UUID?
  var body: some View {
    Panel(title: "快速备忘") {
      TextField("随手记下一个想法…", text: $text, axis: .vertical).lineLimit(2...5)
      HStack {
        Button(editID == nil ? "保存备忘" : "保存修改") {
          let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !v.isEmpty else { return }
          if model.change({ l in
            if let id = editID, let i = l.memos.firstIndex(where: { $0.id == id }) {
              l.memos[i].body = v
            } else {
              l.memos.insert(Memo(v), at: 0)
            }
          }) {
            text = ""
            editID = nil
          }
        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if editID != nil {
          Button("取消编辑") {
            text = ""
            editID = nil
          }
        }
      }
      ForEach(model.library.memos.filter { $0.targetID == nil }) { m in
        VStack(alignment: .leading) {
          Text(m.body)
          HStack {
            Button("转为待办") {
              model.change { _ = try $0.convertMemo(m.id, to: "todo", day: model.today) }
            }
            Button("转为笔记") {
              if model.change({ _ = try $0.convertMemo(m.id, to: "note", day: model.today) }) {
                model.page = "笔记"
              }
            }
            IconAction("编辑", systemImage: "pencil") {
              text = m.body
              editID = m.id
            }
            IconAction("删除", systemImage: "trash") {
              model.delete({ $0.memos.removeAll { $0.id == m.id } }, undo: { $0.memos.append(m) })
            }
          }.font(.caption)
        }.padding(.vertical, 6)
      }
    }
  }
}
