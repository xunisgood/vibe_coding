import LifeCore
import SwiftUI

struct HomeView: View {
  @ObservedObject var model: AppModel
  @State private var title = ""
  @State private var contentWidth: CGFloat = 0
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      let todos = model.library.todos.filter { $0.day == model.today }
      let finished = todos.filter(\.done).count
      HStack(spacing: 22) {
        VStack(alignment: .leading, spacing: 10) {
          Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
          Text("今天，按自己的节奏。")
            .font(.system(size: 25, weight: .semibold))
          Text(
            todos.isEmpty ? "从一件小事开始，给今天一点方向。" : "已完成 \(finished) / \(todos.count) 项待办，所有进展都值得记录。"
          )
          .font(.callout).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        ZStack {
          Circle().stroke(.indigo.opacity(0.09), lineWidth: 7)
          Circle().trim(from: 0, to: todos.isEmpty ? 0 : Double(finished) / Double(todos.count))
            .stroke(.indigo.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .rotationEffect(.degrees(-90))
          VStack(spacing: 3) {
            Text("\(finished)").font(.system(size: 25, weight: .semibold, design: .rounded))
            Text("已完成").font(.system(size: 10)).foregroundStyle(.secondary)
          }
        }.frame(width: 80, height: 80).accessibilityElement(children: .ignore)
          .accessibilityLabel("今日待办已完成 \(finished) 项，共 \(todos.count) 项")
      }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
        .background(
          LinearGradient(
            colors: [.indigo.opacity(0.09), .purple.opacity(0.035), .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 22).strokeBorder(.indigo.opacity(0.08), lineWidth: 1))
      let missed = model.library.missedReminders(now: Date())
      if !missed.isEmpty {
        Panel(title: "错过的提醒 · \(missed.count) 条") {
          ForEach(missed) { r in
            HStack {
              Text(r.title)
              Text(r.date.formatted()).font(.caption).foregroundStyle(.secondary)
              Spacer()
              Button("查看") {
                model.show(r.page, day: r.day)
                model.focusedReminderID = r.id
              }
            }
          }
          Button("已知晓") { model.change { $0.acknowledge(missed) } }
        }
      }
      HStack(alignment: .top, spacing: 18) {
        Panel(title: "今日聚焦") {
          HStack {
            TextField("添加今日待办", text: $title).onSubmit(add)
            Button("添加", action: add).buttonStyle(.borderedProminent).disabled(
              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
          let pending = model.library.todos.filter { $0.day == model.today && !$0.done }
          if pending.isEmpty {
            Text("今日待办已清空，给自己留一点空间。").foregroundStyle(.secondary).padding(.vertical, 12)
          }
          ForEach(pending) { t in
            HStack {
              Toggle(
                t.title,
                isOn: Binding(
                  get: { t.done },
                  set: { v in
                    model.change { l in
                      if let i = l.todos.firstIndex(where: { $0.id == t.id }) {
                        l.todos[i].done = v
                      }
                    }
                  })
              ).toggleStyle(.checkbox)
              Spacer()
              Button("详情") {
                model.show("今日计划", day: model.today)
                model.focusedReminderID = "life.todo." + t.id.uuidString
              }
            }.padding(.vertical, 5)
          }
          TrainingLinks(model: model, day: model.today)
          let completed = model.library.todos.filter { $0.day == model.today && $0.done }
          if !completed.isEmpty {
            DisclosureGroup("已完成 · \(completed.count) 项") {
              ForEach(completed) { t in
                HStack {
                  Text(t.title).strikethrough()
                  Spacer()
                  Button("撤销完成") {
                    model.change { l in
                      if let i = l.todos.firstIndex(where: { $0.id == t.id }) {
                        l.todos[i].done = false
                      }
                    }
                  }
                }
              }
            }
          }
          Button("查看今日计划") { model.show("今日计划", day: model.today) }.padding(.top, 8)
        }.frame(maxWidth: .infinity)
        MemosView(model: model).frame(width: 250)
      }
      let summary = model.library.overview(day: model.today)
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), alignment: .top), count: contentWidth >= 760 ? 4 : 2),
        spacing: 16
      ) {
        Panel(title: "开发工作") {
          summaryIcon("terminal", color: .purple)
          if let id = summary.latestProjectID,
            let p = model.library.projects.first(where: { $0.id == id })
          {
            Text(p.name).font(.headline)
            Text(
              p.entries.filter { $0.kind == "进展" }.max { $0.updated < $1.updated }?.title
                ?? "尚无进展记录"
            ).foregroundStyle(.secondary)
            Button("查看项目") {
              model.selectedProjectID = id
              model.page = "开发工作"
            }
          } else {
            Text("还没有正在进行的项目").foregroundStyle(.secondary)
            Button("管理项目") { model.page = "开发工作" }
          }
        }
        Panel(title: "今日训练") {
          summaryIcon("figure.strengthtraining.traditional", color: .orange)
          Text("\(summary.trainingCount) 次安排 · \(summary.completedTrainings) 次完成")
          Button("查看训练") { model.show("健身计划", day: model.today) }
        }
        Panel(title: "饮食") {
          summaryIcon("fork.knife", color: .green)
          Text("今天已记录 \(summary.recordedMeals) 餐")
          Button("记饮食") { model.show("饮食计划", day: model.today) }
        }
        Panel(title: "游戏娱乐") {
          summaryIcon("gamecontroller", color: .pink)
          Text("今天玩了 \(summary.gameMinutes) 分钟")
          Button("记游戏") { model.show("游戏娱乐", day: model.today) }
        }
      }
    }.onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      contentWidth = $0
    }
    .onAppear { model.ensureTrainings() }
  }
  func summaryIcon(_ symbol: String, color: Color) -> some View {
    Image(systemName: symbol).font(.system(size: 23, weight: .light)).foregroundStyle(color)
      .frame(width: 46, height: 46).background(
        color.opacity(0.085), in: RoundedRectangle(cornerRadius: 15)
      )
      .accessibilityHidden(true)
  }
  func add() {
    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return }
    if model.change({ $0.todos.append(Todo(title: clean, day: model.today)) }) { title = "" }
  }
}
