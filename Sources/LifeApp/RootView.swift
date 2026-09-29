import AppKit
import LifeCore
import SwiftUI

let pages = ["首页总览", "今日计划", "开发工作", "健身计划", "饮食计划", "游戏娱乐", "笔记", "设置与数据"]
let symbols = [
  "house", "checklist", "chevron.left.forwardslash.chevron.right", "dumbbell", "fork.knife",
  "gamecontroller", "note.text", "gearshape",
]
struct RootView: View {
  @ObservedObject var model: AppModel
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 11) {
          Image(systemName: "sparkle").font(.system(size: 24, weight: .light)).foregroundStyle(
            .indigo
          )
          .frame(width: 42, height: 42).background(
            .indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
          VStack(alignment: .leading, spacing: 4) {
            Text("我的日常").font(.system(size: 17, weight: .semibold))
            Text("个人生活中心").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
          }
        }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
        ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
          if i == 6 { Divider().padding(.horizontal, 14).padding(.vertical, 8) }
          if i == 7 { Spacer(minLength: 8) }
          NavigationItem(index: i, selected: model.page == page) {
            model.focusedReminderID = nil
            model.page = page
          }
        }
        HStack(spacing: 6) {
          Image(systemName: "internaldrive").font(.system(size: 10))
          Text("本地保存 · 私人空间").font(.system(size: 10))
        }.foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
      }.padding(10).frame(width: 200).lifeGlass(radius: 24).padding(12)
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Text(model.page).font(.system(size: 28, weight: .bold))
              .accessibilityIdentifier(colorScheme == .dark ? "life-root-dark" : "life-root-light")
            Text(LifeStyle.subtitles[pages.firstIndex(of: model.page) ?? 0])
              .font(.system(size: 12)).foregroundStyle(.secondary)
          }
          Spacer(minLength: 12)
          HStack(spacing: 6) {
            Image(
              systemName: model.dirty || model.locked
                ? "exclamationmark.circle" : "checkmark.circle")
            Text(model.status)
          }.foregroundStyle(model.dirty || model.locked ? Color.red : Color.secondary)
            .font(.system(size: 10, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
            .background(.primary.opacity(0.035), in: Capsule())
          if model.dirty { Button("重试保存") { model.save() } }
        }.padding(.horizontal, 28).padding(.top, 30).padding(.bottom, 24)
        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
              .padding(.horizontal, 28).padding(.bottom, 28)
              .frame(maxWidth: .infinity, alignment: .leading)
          }.onChange(of: model.focusedReminderID) { _, id in
            guard let id else { return }
            Task { @MainActor in
              await Task.yield()
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .top)
              }
            }
          }
        }
        if model.undoAvailable {
          HStack {
            Text("记录已删除")
            Button("撤销") { model.undo() }
            Spacer()
          }.padding(14).lifeGlass(radius: 16).padding(.horizontal, 28).padding(.bottom, 12)
        }
      }
    }.frame(minWidth: 880, minHeight: 620)
      .background(LifeBackdrop())

      .tint(LifeStyle.accent(model.page))
      .controlSize(.large)
      .textFieldStyle(.roundedBorder)
      .alert(
        "需要处理",
        isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
      ) {
        Button("知道了") { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
  }
  @ViewBuilder var content: some View {
    if model.page == "设置与数据" {
      SettingsView(model: model)
    } else if model.page == "今日计划" {
      TodosView(model: model)
    } else if model.page == "健身计划" {
      TrainingsView(model: model)
    } else if model.page == "饮食计划" {
      MealsView(model: model)
    } else if model.page == "游戏娱乐" {
      GamesView(model: model)
    } else if model.page == "开发工作" {
      ProjectsView(model: model)
    } else if model.page == "笔记" {
      NotesView(model: model)
    } else if model.page == "首页总览" {
      HomeView(model: model)
    } else {
      ContentUnavailableView("尚无记录", systemImage: "tray", description: Text("请选择左侧模块"))
    }
  }
}
struct DayPicker: View {
  @ObservedObject var model: AppModel
  var body: some View {
    HStack {
      HStack(spacing: 8) {
        Button {
          model.selectedDate = Calendar.current.date(
            byAdding: .day, value: -1, to: model.selectedDate)!
        } label: {
          Image(systemName: "chevron.left")
        }.help("前一天")
        DatePicker("日期", selection: $model.selectedDate, displayedComponents: .date).labelsHidden()
        Button {
          model.selectedDate = Calendar.current.date(
            byAdding: .day, value: 1, to: model.selectedDate)!
        } label: {
          Image(systemName: "chevron.right")
        }.help("后一天")
        Button("今天") { model.selectedDate = Date() }
      }.padding(7).lifeGlass(radius: 14)
      Spacer()
    }
  }
}
struct Panel<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
      VStack(alignment: .leading, spacing: 12) { content }
    }.padding(22).frame(maxWidth: .infinity, alignment: .leading).lifeCard()
  }
}
