import SwiftUI
import AppKit
import LifeCore
let pages = ["首页总览","今日计划","开发工作","健身计划","饮食计划","游戏娱乐","笔记","设置与数据"]
let symbols = ["house","checklist","chevron.left.forwardslash.chevron.right","dumbbell","fork.knife","gamecontroller","note.text","gearshape"]
struct RootView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("我的日常").font(.title2.bold()).padding(.vertical, 20)
                ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                    if i == 7 { Spacer() }
                    Button { model.page = page } label: {
                        Label(page, systemImage: symbols[i]).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(model.page == page ? Color.accentColor.opacity(0.13) : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityIdentifier("nav-\(i)")
                }
                Text("只在本机 · 无需联网").font(.caption).foregroundStyle(.secondary).padding(.top, 12)
            }.padding(16).frame(width: 190).background(.quaternary.opacity(0.35))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text(model.page).font(.largeTitle.bold()); Spacer(); Text(model.status).foregroundStyle(model.dirty || model.locked ? .red : .secondary).font(.caption); if model.dirty { Button("重试保存") { model.save() } } }.padding(24)
                ScrollView { VStack(alignment: .leading, spacing: 18) { content }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: .infinity, alignment: .leading) }
                if model.undoAvailable { HStack { Text("记录已删除"); Button("撤销") { model.undo() }; Spacer() }.padding(10).background(.quaternary) }
            }
        }.frame(minWidth: 880, minHeight: 620)
        .alert("需要处理", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("知道了") { model.error = nil } } message: { Text(model.error ?? "") }
    }
    @ViewBuilder var content: some View {
        if model.page == "设置与数据" {
            SettingsView(model: model)
        } else if model.page == "今日计划" { TodosView(model: model)
        } else if model.page == "健身计划" { TrainingsView(model: model)
        } else if model.page == "笔记" { NotesView(model: model)
        } else if model.page == "首页总览" { MemosView(model: model)
        } else { ContentUnavailableView("尚无记录", systemImage: "tray", description: Text("应用基础已就绪，业务模块正在开发。")) }
    }
}
struct DayPicker: View {
    @ObservedObject var model: AppModel
    var body: some View { HStack {
        Button { model.selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: model.selectedDate)! } label: { Image(systemName: "chevron.left") }.help("前一天")
        DatePicker("日期", selection: $model.selectedDate, displayedComponents: .date).labelsHidden()
        Button { model.selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: model.selectedDate)! } label: { Image(systemName: "chevron.right") }.help("后一天")
        Button("今天") { model.selectedDate = Date() }; Spacer()
    } }
}
struct Panel<Content: View>: View {
    let title: String; @ViewBuilder var content: Content
    var body: some View { GroupBox { VStack(alignment: .leading, spacing: 12) { content }.padding(12).frame(maxWidth: .infinity, alignment: .leading) } label: { Text(title).font(.headline) } }
}
