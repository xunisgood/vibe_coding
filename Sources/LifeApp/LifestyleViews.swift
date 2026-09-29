import SwiftUI
import LifeCore
struct MealsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        DayPicker(model:model)
        let n=model.library.nutrition(on:model.day)
        Panel(title:n.partial ? "已填写部分合计" : "当天实际合计") {
            HStack { Text("\(n.calories.formatted()) kcal").font(.title);Text("蛋白质 \(n.protein.formatted()) g").font(.title3);Spacer();Text("已记录 \(n.recordedMeals) 餐").foregroundStyle(.secondary) }
            Text("仅合计实际饮食中手动填写的营养值，空白代表未记录。").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(["早餐","午餐","晚餐","加餐"],id:\.self) { slot in MealEditor(model:model,day:model.day,slot:slot).id(model.day+slot) }
    }
}
struct MealEditor:View {
    @ObservedObject var model:AppModel; let day:String; let slot:String
    var meal:Meal { model.library.meals.first { $0.day == day && $0.slot == slot } ?? Meal(day:day,slot:slot) }
    var body:some View { Panel(title:slot) {
        HStack(alignment:.top,spacing:20) {
            VStack(alignment:.leading) { Text("计划吃什么").font(.caption);TextField("可选",text:binding(\.planned),axis:.vertical).lineLimit(2...4) }
            VStack(alignment:.leading) { Text("实际吃了什么").font(.caption);TextField("未记录",text:binding(\.actual),axis:.vertical).lineLimit(2...4) }
        }
        HStack {
            Button("按计划吃了") { model.change { try $0.eatAsPlanned(meal.id) } }.disabled(meal.planned.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            Text("热量"); TextField("未记录",value:binding(\.calories),format:.number).frame(width:100);Text("kcal")
            Text("蛋白质");TextField("未记录",value:binding(\.protein),format:.number).frame(width:100);Text("g");Spacer()
            Button("清除本餐") { let m=meal; model.delete({ $0.meals.removeAll { $0.id == m.id } },undo:{ $0.meals.append(m) }) }.disabled(!model.library.meals.contains { $0.day == day && $0.slot == slot })
        }
    } }
    func binding<T>(_ path:WritableKeyPath<Meal,T>) -> Binding<T> {
        Binding(get:{ meal[keyPath:path] },set:{ value in model.change { l in if let i=l.meals.firstIndex(where:{ $0.day == day && $0.slot == slot }) { l.meals[i][keyPath:path]=value } else { var m=Meal(day:day,slot:slot);m[keyPath:path]=value;l.meals.append(m) } } })
    }
}
struct GamesView:View {
    @ObservedObject var model:AppModel; @State private var edit:Game?
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            DayPicker(model:model)
            HStack { Text("今日游戏：\(model.library.gameMinutes(on:model.day)) 分钟").font(.title2);Spacer();Button("记录游戏") { edit=Game(day:model.day,name:"",minutes:30) }.buttonStyle(.borderedProminent) }
            let games=model.library.games.filter { $0.day == model.day }
            if games.isEmpty { ContentUnavailableView("还没有游戏记录",systemImage:"gamecontroller",description:Text("玩过之后，记下名称和时长即可")) }
            ForEach(games) { g in
                Panel(title:g.name) {
                    HStack {
                        Text("\(g.minutes/60) 小时 \(g.minutes%60) 分钟")
                        Spacer()
                        Button("编辑") { edit=g }
                        Button("删除") {
                            model.delete({ $0.games.removeAll { $0.id == g.id } },undo:{ $0.games.append(g) })
                        }
                    }
                    if !g.note.isEmpty { Text(g.note).foregroundStyle(.secondary) }
                }
            }
        }.sheet(item:$edit) { g in GameEditor(model:model,original:g) }
    }
}
struct GameEditor:View {
    @ObservedObject var model:AppModel; @Environment(\.dismiss) var dismiss
    @State var value:Game; @State var hours:Int; @State var minutes:Int; @State var date:Date; @State private var error:String?
    init(model:AppModel,original:Game) { self.model=model;_value=State(initialValue:original);_hours=State(initialValue:original.minutes/60);_minutes=State(initialValue:original.minutes%60);_date=State(initialValue:Day.date(original.day)!) }
    var body:some View { VStack(alignment:.leading,spacing:16) {
        Text("记录游戏").font(.title2);DatePicker("日期",selection:$date,displayedComponents:.date)
        HStack { TextField("游戏名称（必填）",text:$value.name);Menu("最近玩过") { ForEach(Array(Set(model.library.games.map(\.name))).sorted(),id:\.self) { n in Button(n) { value.name=n } } } }
        HStack { TextField("小时",value:$hours,format:.number);Text("小时");TextField("分钟",value:$minutes,format:.number);Text("分钟") }
        TextField("备注（可选）",text:$value.note,axis:.vertical).lineLimit(3...5)
        if let error { Text(error).foregroundStyle(.red) }
        HStack { Button("取消") { dismiss() };Spacer();Button("保存") {
            do { value.minutes=try GameDuration.minutes(hours:hours,minutes:minutes);value.day=Day.key(date)
                if model.change({ l in if let i=l.games.firstIndex(where:{ $0.id == value.id }) { l.games[i]=value } else { l.games.append(value) } }) { dismiss() }
            } catch { self.error=error.localizedDescription }
        }.buttonStyle(.borderedProminent).disabled(value.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
    }.padding(24).frame(width:460) }
}
struct ProjectsView:View {
    @ObservedObject var model:AppModel; @State private var selected:UUID?; @State private var showArchived=false; @State private var editProject:Project?
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Toggle("查看归档",isOn:$showArchived);Spacer();Button("新建项目") { editProject=Project("") }.buttonStyle(.borderedProminent) }
            HStack(alignment:.top,spacing:18) {
                VStack(alignment:.leading,spacing:12) {
                    ForEach(model.library.projects.filter { $0.archived == showArchived }.sorted { $0.updated > $1.updated }) { p in
                        Button { selected=p.id } label: { VStack(alignment:.leading,spacing:5) { Text(p.name).font(.headline);Text(p.entries.first { ["任务","问题"].contains($0.kind) && $0.status != "已完成" }?.title ?? "暂无待处理任务").font(.caption).foregroundStyle(.secondary);Text(p.updated.formatted(date:.abbreviated,time:.omitted)).font(.caption2) }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(selected == p.id ? Color.accentColor.opacity(0.12) : .clear).cornerRadius(8) }.buttonStyle(.plain)
                    }
                    if !model.library.projects.contains(where:{ $0.archived == showArchived }) { Text("暂无项目").foregroundStyle(.secondary) }
                }.frame(width:200)
                Divider()
                if let id=selected,let p=model.library.projects.first(where:{ $0.id == id }) {
                    VStack(alignment:.leading,spacing:16) {
                        HStack { Text(p.name).font(.title2);Spacer();Button("编辑") { editProject=p };Button(p.archived ? "恢复" : "归档") { model.change { try $0.archiveProject(id,archived:!p.archived) }; selected=nil }
                            Button("删除") { if model.confirm("删除项目？",detail:"将删除“\(p.name)”及其 \(p.entries.count) 条任务、问题、笔记和进展。") { model.delete({ $0.projects.removeAll { $0.id == id } },undo:{ $0.projects.append(p) });selected=nil } }
                        }
                        if !p.detail.isEmpty { Text(p.detail).foregroundStyle(.secondary) }
                        ProjectEntriesView(model:model,projectID:id).id(id)
                    }
                } else { ContentUnavailableView("选择一个项目",systemImage:"folder",description:Text("记录任务、问题和开发进展")) }
            }
        }.onAppear { if let id=model.selectedProjectID { selected=id;showArchived=model.library.projects.first { $0.id == id }?.archived ?? false } }.sheet(item:$editProject) { p in ProjectEditor(model:model,original:p) }
    }
}
struct ProjectEditor:View {
    @ObservedObject var model:AppModel; @Environment(\.dismiss) var dismiss; @State var value:Project
    init(model:AppModel,original:Project) { self.model=model;_value=State(initialValue:original) }
    var body:some View { VStack(alignment:.leading,spacing:16) {
        Text("项目详情").font(.title2);TextField("项目名称（必填）",text:$value.name);TextField("项目说明",text:$value.detail,axis:.vertical).lineLimit(3...5)
        HStack { Button("取消") { dismiss() };Spacer();Button("保存") { value.updated=Date();if model.change({ l in if let i=l.projects.firstIndex(where:{ $0.id == value.id }) { l.projects[i]=value } else { l.projects.append(value) } }) { dismiss() } }.buttonStyle(.borderedProminent).disabled(value.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
    }.padding(24).frame(width:450) }
}
struct ProjectEntriesView:View {
    @ObservedObject var model:AppModel; let projectID:UUID; @State private var kind="任务"; @State private var edit:DevEntry?
    var entries:[DevEntry] { model.library.projects.first { $0.id == projectID }?.entries.filter { $0.kind == kind }.sorted { $0.day == $1.day ? $0.updated > $1.updated : $0.day > $1.day } ?? [] }
    var body:some View { VStack(alignment:.leading,spacing:12) {
        Picker("内容",selection:$kind) { ForEach(["任务","问题","笔记","进展"],id:\.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
        Button("添加\(kind)") { var e=DevEntry();e.kind=kind;edit=e }
        if entries.isEmpty { Text("暂无\(kind)").foregroundStyle(.secondary) }
        ForEach(entries) { e in Panel(title:e.title) {
            HStack { Text(e.day).font(.caption); if kind == "任务" || kind == "问题" { Text(e.status).font(.caption).foregroundStyle(.secondary) };Spacer();Button("编辑") { edit=e };Button("删除") {
                model.delete({ l in if let i=l.projects.firstIndex(where:{ $0.id == projectID }) { l.projects[i].entries.removeAll { $0.id == e.id };l.projects[i].updated=Date() } },undo:{ l in if let i=l.projects.firstIndex(where:{ $0.id == projectID }) { l.projects[i].entries.append(e) } })
            } };if !e.body.isEmpty { Text(e.body).textSelection(.enabled) }
        } }
    }.sheet(item:$edit) { e in EntryEditor(model:model,projectID:projectID,original:e) } }
}
struct EntryEditor:View {
    @ObservedObject var model:AppModel;let projectID:UUID;@Environment(\.dismiss) var dismiss;@State var value:DevEntry;@State var date:Date
    init(model:AppModel,projectID:UUID,original:DevEntry) { self.model=model;self.projectID=projectID;_value=State(initialValue:original);_date=State(initialValue:Day.date(original.day)!) }
    var body:some View { VStack(alignment:.leading,spacing:16) {
        Text(value.kind).font(.title2);TextField("标题（必填）",text:$value.title);DatePicker("日期",selection:$date,displayedComponents:.date)
        if value.kind == "任务" || value.kind == "问题" { Picker("状态",selection:$value.status) { ForEach(["待处理","进行中","已完成"],id:\.self) { Text($0).tag($0) } } }
        Text("内容 / 问题 / 下一步").font(.caption);TextEditor(text:$value.body).frame(height:190)
        HStack { Button("取消") { dismiss() };Spacer();Button("保存") { value.day=Day.key(date);if model.change({ try $0.saveEntry(value,projectID:projectID) }) { dismiss() } }.buttonStyle(.borderedProminent).disabled(value.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
    }.padding(24).frame(width:500) }
}
