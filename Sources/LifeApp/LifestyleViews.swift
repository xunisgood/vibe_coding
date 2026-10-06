import LifeCore
import SwiftUI

struct MealsView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    let n = model.library.nutrition(on: model.day)
    HStack(spacing: 16) {
      MetricTile(
        label: n.partial ? "已填写部分合计" : "当天实际合计", value: "\(n.calories.formatted()) kcal",
        detail: "仅统计实际饮食的已填热量", symbol: "flame", color: .orange)
      MetricTile(
        label: "蛋白质", value: "\(n.protein.formatted()) g", detail: "已记录 \(n.recordedMeals) 餐",
        symbol: "leaf", color: .green)
    }
    Text("仅合计实际饮食中手动填写的营养值，空白代表未记录。")
      .font(.caption).foregroundStyle(.secondary)
    ForEach(["早餐", "午餐", "晚餐", "加餐"], id: \.self) { slot in
      MealEditor(model: model, day: model.day, slot: slot).id(model.day + slot)
    }
  }
}
struct MealEditor: View {
  @ObservedObject var model: AppModel
  let day: String
  let slot: String
  var meal: Meal {
    model.library.meals.first { $0.day == day && $0.slot == slot } ?? Meal(day: day, slot: slot)
  }
  var body: some View {
    Panel(title: slot) {
      HStack(spacing: 8) {
        Image(
          systemName: slot == "早餐"
            ? "sunrise" : slot == "午餐" ? "sun.max" : slot == "晚餐" ? "moon" : "cup.and.saucer"
        )
        .foregroundStyle(.green)
        Text(slot == "加餐" ? "一点补充，适量就好" : "计划与实际，各自记录")
          .font(.caption).foregroundStyle(.secondary)
      }
      HStack(alignment: .top, spacing: 20) {
        VStack(alignment: .leading) {
          Text("计划吃什么").font(.caption)
          TextField("可选", text: binding(\.planned), axis: .vertical).lineLimit(2...4)
        }
        VStack(alignment: .leading) {
          Text("实际吃了什么").font(.caption)
          TextField("未记录", text: binding(\.actual), axis: .vertical).lineLimit(2...4)
        }
      }
      HStack {
        Button("按计划吃了") { model.change { try $0.eatAsPlanned(meal.id) } }.disabled(
          meal.planned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Spacer()
        IconAction("清除本餐", systemImage: "trash") {
          let m = meal
          model.delete({ $0.meals.removeAll { $0.id == m.id } }, undo: { $0.meals.append(m) })
        }.disabled(!model.library.meals.contains { $0.day == day && $0.slot == slot })
      }
      HStack {
        Text("热量")
        TextField("未记录", value: binding(\.calories), format: .number).frame(width: 100)
        Text("kcal")
        Text("蛋白质")
        TextField("未记录", value: binding(\.protein), format: .number).frame(width: 100)
        Text("g")
        Spacer()
      }
    }
  }
  func binding<T>(_ path: WritableKeyPath<Meal, T>) -> Binding<T> {
    Binding(
      get: { meal[keyPath: path] },
      set: { value in
        model.change { l in
          if let i = l.meals.firstIndex(where: { $0.day == day && $0.slot == slot }) {
            l.meals[i][keyPath: path] = value
          } else {
            var m = Meal(day: day, slot: slot)
            m[keyPath: path] = value
            l.meals.append(m)
          }
        }
      })
  }
}
struct GamesView: View {
  @ObservedObject var model: AppModel
  @State private var edit: Game?
  @State private var query = ""
  @FocusState private var searchFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text("今日游戏：\(model.library.gameMinutes(on:model.day)) 分钟")
            .font(.system(size: 23, weight: .semibold, design: .rounded)).monospacedDigit()
          Text("快乐也值得被记录").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()

      }
      TextField("搜索游戏名称", text: $query).focused($searchFocused)
      let games = model.library.games.filter {
        $0.day == model.day && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
      }
      if games.isEmpty {
        LifeEmptyState(
          query.isEmpty ? "还没有游戏记录" : "没有匹配的游戏", systemImage: "gamecontroller",
          description: Text("可切换日期或调整搜索内容"))
      }
      ForEach(games) { g in
        Panel(title: g.name) {
          HStack {
            Label("\(g.minutes/60) 小时 \(g.minutes%60) 分钟", systemImage: "clock")
              .font(.system(size: 19, weight: .medium, design: .rounded)).foregroundStyle(.pink)
            Spacer()
            IconAction("编辑", systemImage: "pencil") { edit = g }
            IconAction("删除", systemImage: "trash") {
              model.delete({ $0.games.removeAll { $0.id == g.id } }, undo: { $0.games.append(g) })
            }
          }
          if !g.note.isEmpty { Text(g.note).foregroundStyle(.secondary) }
        }
      }
    }.onChange(of: model.searchRequest) { _, _ in searchFocused = true }
      .onChange(of: model.newRequest) { _, _ in edit = Game(day: model.day, name: "", minutes: 30) }
      .sheet(item: $edit) { g in GameEditor(model: model, original: g) }
  }
}
struct GameEditor: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) var dismiss
  @State var value: Game
  @State var hours: Int
  @State var minutes: Int
  @State var date: Date
  @State private var error: String?
  init(model: AppModel, original: Game) {
    self.model = model
    _value = State(initialValue: original)
    _hours = State(initialValue: original.minutes / 60)
    _minutes = State(initialValue: original.minutes % 60)
    _date = State(initialValue: Day.date(original.day)!)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("记录游戏").font(.title2)
      DatePicker("日期", selection: $date, displayedComponents: .date)
      HStack {
        TextField("游戏名称（必填）", text: $value.name)
        Menu("最近玩过") {
          ForEach(Array(Set(model.library.games.map(\.name))).sorted(), id: \.self) { n in
            Button(n) { value.name = n }
          }
        }
      }
      HStack {
        TextField("小时", value: $hours, format: .number)
        Text("小时")
        TextField("分钟", value: $minutes, format: .number)
        Text("分钟")
      }
      TextField("备注（可选）", text: $value.note, axis: .vertical).lineLimit(3...5)
      if let error { Text(error).foregroundStyle(.red) }
      HStack {
        Button("取消") { dismiss() }
        Spacer()
        Button("保存") {
          do {
            value.minutes = try GameDuration.minutes(hours: hours, minutes: minutes)
            value.day = Day.key(date)
            if model.change({ l in
              if let i = l.games.firstIndex(where: { $0.id == value.id }) {
                l.games[i] = value
              } else {
                l.games.append(value)
              }
            }) {
              dismiss()
            }
          } catch { self.error = error.localizedDescription }
        }.buttonStyle(.borderedProminent).disabled(
          value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 460).background(LifeBackdrop())
  }
}
struct ProjectsView: View {
  @ObservedObject var model: AppModel
  @State private var showArchived = false
  @State private var editProject: Project?
  @FocusState private var rowFocused: UUID?
  var projects: [Project] {
    model.library.projects.filter { $0.archived == showArchived }.sorted { $0.updated > $1.updated }
  }
  var body: some View {
    HSplitView {
      projectList
      projectDetail
    }.onAppear {
      if let id = model.selectedProjectID {
        showArchived = model.library.projects.first { $0.id == id }?.archived ?? false
      }
    }
    .onChange(of: model.newRequest) { _, _ in editProject = Project("") }
    .onChange(of: showArchived) { _, value in
      if !model.library.projects.contains(where: {
        $0.id == model.selectedProjectID && $0.archived == value
      }) {
        model.selectedProjectID = nil
      }
    }
    .sheet(item: $editProject) { p in ProjectEditor(model: model, original: p) }
  }
  private var projectList: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("查看归档", isOn: $showArchived)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(projects) { p in projectRow(p) }
          if projects.isEmpty { Text("暂无项目").foregroundStyle(.secondary) }
        }
      }
    }.padding(12).frame(minWidth: 190, idealWidth: 214, maxWidth: 270, maxHeight: .infinity)
      .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
  }
  private func projectRow(_ p: Project) -> some View {
    Button {
      model.selectedProjectID = p.id
      rowFocused = p.id
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        Text(p.name).font(.headline).lineLimit(2)
        Text(
          p.entries.first { ["任务", "问题"].contains($0.kind) && $0.status != "已完成" }?.title
            ?? "暂无待处理任务"
        )
        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        Text(p.updated.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
      }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(model.selectedProjectID == p.id ? Color.accentColor.opacity(0.12) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
    }.buttonStyle(.plain).focusable().focused($rowFocused, equals: p.id)
      .onKeyPress(.downArrow) {
        move(p.id, 1)
        return .handled
      }
      .onKeyPress(.upArrow) {
        move(p.id, -1)
        return .handled
      }
      .contextMenu {
        Button("编辑项目") { editProject = p }
        Button(p.archived ? "恢复" : "归档") { archive(p) }
        Button("删除项目", role: .destructive) { remove(p) }
      }
  }
  private var projectDetail: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let id = model.selectedProjectID,
        let p = model.library.projects.first(where: { $0.id == id })
      {
        HStack {
          Text(p.name).font(.title2).lineLimit(2)
          Spacer()
          IconAction("编辑", systemImage: "pencil") { editProject = p }
          Button(p.archived ? "恢复" : "归档") { archive(p) }
          IconAction("删除", systemImage: "trash") { remove(p) }
        }
        if !p.detail.isEmpty { Text(p.detail).foregroundStyle(.secondary).lineLimit(3) }
        ProjectEntriesView(model: model, projectID: id).id(id)
      } else {
        LifeEmptyState("选择一个项目", systemImage: "folder", description: Text("记录任务、问题和开发进展"))
        Spacer()
      }
    }.padding(.leading, 16).frame(minWidth: 310, maxWidth: .infinity, maxHeight: .infinity)
  }
  func move(_ id: UUID, _ delta: Int) {
    guard let i = projects.firstIndex(where: { $0.id == id }), !projects.isEmpty else { return }
    let p = projects[min(max(i + delta, 0), projects.count - 1)]
    model.selectedProjectID = p.id
    rowFocused = p.id
  }
  func archive(_ p: Project) {
    if model.change({ try $0.archiveProject(p.id, archived: !p.archived) }) {
      model.selectedProjectID = nil
    }
  }
  func remove(_ p: Project) {
    guard model.confirm("删除项目？", detail: "将删除“\(p.name)”及其 \(p.entries.count) 条任务、问题、笔记和进展。") else {
      return
    }
    model.delete({ $0.projects.removeAll { $0.id == p.id } }, undo: { $0.projects.append(p) })
    if !model.library.projects.contains(where: { $0.id == p.id }) { model.selectedProjectID = nil }
  }
}
struct ProjectEditor: View {
  @ObservedObject var model: AppModel
  @Environment(\.dismiss) var dismiss
  @State var value: Project
  init(model: AppModel, original: Project) {
    self.model = model
    _value = State(initialValue: original)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("项目详情").font(.title2)
      TextField("项目名称（必填）", text: $value.name)
      TextField("项目说明", text: $value.detail, axis: .vertical).lineLimit(3...5)
      HStack {
        Button("取消") { dismiss() }
        Spacer()
        Button("保存") {
          value.updated = Date()
          if model.change({ l in
            if let i = l.projects.firstIndex(where: { $0.id == value.id }) {
              l.projects[i] = value
            } else {
              l.projects.append(value)
            }
          }) {
            dismiss()
          }
        }.buttonStyle(.borderedProminent).disabled(
          value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 450).background(LifeBackdrop())
  }
}
struct ProjectEntriesView: View {
  @ObservedObject var model: AppModel
  let projectID: UUID
  @State private var kind = "任务"
  @State private var edit: DevEntry?
  var entries: [DevEntry] {
    model.library.projects.first { $0.id == projectID }?.entries.filter { $0.kind == kind }.sorted {
      $0.day == $1.day ? $0.updated > $1.updated : $0.day > $1.day
    } ?? []
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("内容", selection: $kind) {
        ForEach(["任务", "问题", "笔记", "进展"], id: \.self) { Text($0).tag($0) }
      }.pickerStyle(.segmented)
      IconAction("添加\(kind)", systemImage: "plus") {
        var e = DevEntry()
        e.kind = kind
        edit = e
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if entries.isEmpty { Text("暂无\(kind)").foregroundStyle(.secondary) }
          ForEach(entries) { e in
            Panel(title: e.title) {
              HStack {
                Text(e.day).font(.caption)
                if kind == "任务" || kind == "问题" {
                  Text(e.status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                IconAction("编辑", systemImage: "pencil") { edit = e }
                IconAction("删除", systemImage: "trash") {
                  model.delete(
                    { l in
                      if let i = l.projects.firstIndex(where: { $0.id == projectID }) {
                        l.projects[i].entries.removeAll { $0.id == e.id }
                        l.projects[i].updated = Date()
                      }
                    },
                    undo: { l in
                      if let i = l.projects.firstIndex(where: { $0.id == projectID }) {
                        l.projects[i].entries.append(e)
                      }
                    })
                }
              }
              if !e.body.isEmpty { Text(e.body).textSelection(.enabled) }
            }
          }
        }
      }
    }.sheet(item: $edit) { e in EntryEditor(model: model, projectID: projectID, original: e) }
  }
}
struct EntryEditor: View {
  @ObservedObject var model: AppModel
  let projectID: UUID
  @Environment(\.dismiss) var dismiss
  @State var value: DevEntry
  @State var date: Date
  init(model: AppModel, projectID: UUID, original: DevEntry) {
    self.model = model
    self.projectID = projectID
    _value = State(initialValue: original)
    _date = State(initialValue: Day.date(original.day)!)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(value.kind).font(.title2)
      TextField("标题（必填）", text: $value.title)
      DatePicker("日期", selection: $date, displayedComponents: .date)
      if value.kind == "任务" || value.kind == "问题" {
        Picker("状态", selection: $value.status) {
          ForEach(["待处理", "进行中", "已完成"], id: \.self) { Text($0).tag($0) }
        }
      }
      Text("内容 / 问题 / 下一步").font(.caption)
      TextEditor(text: $value.body).scrollContentBackground(.hidden).frame(height: 190).padding(12)
        .lifeCard(radius: 12)
      HStack {
        Button("取消") { dismiss() }
        Spacer()
        Button("保存") {
          value.day = Day.key(date)
          if model.change({ try $0.saveEntry(value, projectID: projectID) }) { dismiss() }
        }.buttonStyle(.borderedProminent).disabled(
          value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }.padding(28).frame(width: 500).background(LifeBackdrop())
  }
}
