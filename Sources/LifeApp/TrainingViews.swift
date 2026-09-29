import SwiftUI
import LifeCore
struct TrainingsView: View {
    @ObservedObject var model: AppModel
    @State private var plan: TrainingPlan?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DayPicker(model: model)
            HStack { Text("记录实际训练，计划不会被覆盖。").foregroundStyle(.secondary); Spacer(); Button("新建训练安排") { var p = TrainingPlan(); p.start = model.day; p.once = model.day; plan = p }.buttonStyle(.borderedProminent) }
            ForEach(model.library.trainings.filter { $0.day == model.day }) { t in TrainingRecordView(model: model, id: t.id) }
            if !model.library.trainings.contains(where: { $0.day == model.day }) { ContentUnavailableView("这一天没有训练安排", systemImage: "dumbbell", description: Text("可添加一次性或每周重复的训练")) }
            Panel(title: "训练安排") {
                ForEach(model.library.plans) { p in
                    HStack { VStack(alignment: .leading) { Text(p.name).font(.headline); Text(p.end.map { "已于 \($0) 结束" } ?? p.once.map { "单次 · \($0)" } ?? "每周：" + p.weekdays.sorted().map { ["","日","一","二","三","四","五","六"][$0] }.joined(separator: "、")).font(.caption).foregroundStyle(.secondary) }; Spacer()
                        Button("修改后续") { plan = p }
                        if p.end == nil || p.end! >= model.today { Button("取消后续") { if model.confirm("取消后续训练？", detail: "将移除今天及之后未开始的安排和提醒，保留已有实际记录和历史。") { model.change { $0.cancelPlan(p.id, from: model.today) } } } }
                    }.padding(.vertical, 6)
                }
            }
            DisclosureGroup("训练历史") { ForEach(model.library.trainings.filter { $0.day < model.today }.reversed()) { t in Button { model.selectedDate = Day.date(t.day)! } label: { HStack { Text(t.day); Text(t.name); Spacer(); Text(t.status) } }.buttonStyle(.plain).padding(6) } }
        }.onAppear { model.ensureTrainings() }.onChange(of: model.day) { _, _ in model.ensureTrainings() }
        .sheet(item: $plan) { p in PlanEditor(model: model, original: p) }
    }
}
struct PlanEditor: View {
    @ObservedObject var model: AppModel; @Environment(\.dismiss) var dismiss
    @State var plan: TrainingPlan; @State var date: Date; @State var weekly: Bool; @State var remind: Bool; @State var time: Date
    init(model: AppModel, original: TrainingPlan) {
        self.model=model; _plan=State(initialValue:original); _date=State(initialValue:Day.date(original.once ?? original.start)!); _weekly=State(initialValue:original.once == nil); _remind=State(initialValue:original.reminderMinutes != nil)
        _time=State(initialValue:Calendar.current.date(byAdding:.minute,value:original.reminderMinutes ?? 1110,to:Calendar.current.startOfDay(for:Date()))!)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练安排").font(.title2)
            TextField("训练名称（必填）", text:$plan.name)
            Toggle("每周重复",isOn:$weekly)
            DatePicker(weekly ? "开始日期" : "训练日期",selection:$date,displayedComponents:.date)
            if weekly { HStack { ForEach(1...7,id:\.self) { d in Toggle(["","日","一","二","三","四","五","六"][d],isOn:Binding(get:{ plan.weekdays.contains(d) },set:{ v in if v { plan.weekdays.append(d) } else { plan.weekdays.removeAll { $0 == d } } })).toggleStyle(.button) } } }
            Toggle("提醒",isOn:$remind); if remind { DatePicker("时间",selection:$time,displayedComponents:.hourAndMinute) }
            ScrollView { VStack(spacing:12) { ForEach($plan.exercises) { $e in ExercisePlanEditor(exercise:$e); Button("移除动作") { plan.exercises.removeAll { $0.id == e.id } } } } }.frame(maxHeight:260)
            Button("添加动作") { plan.exercises.append(Exercise()) }
            HStack { Button("取消") { dismiss() }; Spacer(); Button("保存安排") {
                plan.start=Day.key(date); plan.once=weekly ? nil : Day.key(date)
                let c=Calendar.current.dateComponents([.hour,.minute],from:time); plan.reminderMinutes=remind ? c.hour!*60+c.minute! : nil
                if model.change({ l in if l.plans.contains(where:{ $0.id == plan.id }) { try l.updatePlan(plan,from:model.today) } else { l.plans.append(plan); l.materialize(from:plan.start,through:Day.adding(45,to:max(plan.start,model.today))) } }) { dismiss() }
            }.buttonStyle(.borderedProminent).disabled(plan.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || (weekly && plan.weekdays.isEmpty) || plan.exercises.contains { $0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }) }
        }.padding(24).frame(width:580)
    }
}
struct ExercisePlanEditor: View {
    @Binding var exercise: Exercise
    var body: some View { GroupBox {
        VStack(alignment:.leading,spacing:10) {
            HStack { TextField("动作名称",text:$exercise.name); Picker("类型",selection:$exercise.kind) { Text("力量").tag("力量");Text("有氧").tag("有氧") }.frame(width:140) }
            if exercise.kind == "力量" { HStack { Stepper("\(exercise.plannedSets) 组",value:$exercise.plannedSets,in:1...100); Stepper("\(exercise.plannedReps) 次",value:$exercise.plannedReps,in:1...1000); TextField("kg",value:$exercise.plannedWeight,format:.number).frame(width:70);Text("kg") } }
            else { Stepper("\(exercise.plannedMinutes) 分钟",value:$exercise.plannedMinutes,in:1...1440) }
        }.padding(8)
    } }
}
struct TrainingRecordView: View {
    @ObservedObject var model: AppModel; let id: String
    @State private var single: Training?
    var training: Training? { model.library.trainings.first { $0.id == id } }
    var body: some View {
        if let t=training {
            Panel(title:t.name) {
                HStack { Text(t.status).foregroundStyle(.secondary); if let r=t.reminder { Text("提醒 " + r.formatted(date:.omitted,time:.shortened)).font(.caption) }; Spacer(); Button("只改这一次") { single=t } }
                ForEach(t.exercises) { e in
                    VStack(alignment:.leading,spacing:8) {
                        Text(e.name).font(.headline)
                        if e.kind == "力量" {
                            Text("计划 \(e.plannedSets) 组 × \(e.plannedReps) 次 · \(e.plannedWeight.formatted()) kg").font(.caption).foregroundStyle(.secondary)
                            ForEach(Array(e.sets.enumerated()),id:\.element.id) { index,s in
                                HStack {
                                    Text("第 \(index+1) 组").frame(width:60)
                                    TextField("次数",value:setBinding(e.id,s.id,\.reps),format:.number).frame(width:75)
                                    TextField("重量",value:setBinding(e.id,s.id,\.weight),format:.number).frame(width:75);Text("kg")
                                    Toggle("完成",isOn:setBinding(e.id,s.id,\.done)); Spacer()
                                    Button("删除组") { mutate { t in if let i=t.exercises.firstIndex(where:{ $0.id == e.id }) { t.exercises[i].sets.removeAll { $0.id == s.id } } } }
                                }
                            }
                            Button("记录一组") { mutate { t in if let i=t.exercises.firstIndex(where:{ $0.id == e.id }) { t.exercises[i].sets.append(SetRecord()); if t.status == "未开始" { t.status="进行中" } } } }
                        } else {
                            Text("计划 \(e.plannedMinutes) 分钟").font(.caption)
                            TextField("实际分钟数",value:Binding(get:{ training?.exercises.first { $0.id == e.id }?.actualMinutes },set:{ v in mutate { t in if let i=t.exercises.firstIndex(where:{ $0.id == e.id }) { t.exercises[i].actualMinutes=v; if t.status == "未开始" { t.status="进行中" } } } }),format:.number).frame(width:150)
                        }
                    }.padding(.vertical,8)
                }
                HStack {
                    Button("完成训练") { model.change { try $0.setTrainingStatus(id,"已完成") } }.buttonStyle(.borderedProminent)
                    Button("跳过") { model.change { try $0.setTrainingStatus(id,"已跳过") } }
                    if t.status == "已完成" || t.status == "已跳过" { Button("恢复进行中") { model.change { try $0.setTrainingStatus(id,"进行中") } } }
                }
            }.sheet(item:$single) { value in SingleTrainingEditor(model:model,original:value) }
        }
    }
    func mutate(_ action:(inout Training)->Void) { model.change { l in if let i=l.trainings.firstIndex(where:{ $0.id == id }) { action(&l.trainings[i]) } } }
    func setBinding<T>(_ exercise:UUID,_ set:UUID,_ key:WritableKeyPath<SetRecord,T>) -> Binding<T> {
        let fallback=training!.exercises.first { $0.id == exercise }!.sets.first { $0.id == set }![keyPath:key]
        return Binding(get:{ training?.exercises.first { $0.id == exercise }?.sets.first { $0.id == set }?[keyPath:key] ?? fallback },set:{ v in mutate { t in if let i=t.exercises.firstIndex(where:{ $0.id == exercise }),let j=t.exercises[i].sets.firstIndex(where:{ $0.id == set }) { t.exercises[i].sets[j][keyPath:key]=v; if t.status == "未开始" { t.status="进行中" } } } })
    }
}
struct SingleTrainingEditor:View {
    @ObservedObject var model:AppModel; @Environment(\.dismiss) var dismiss; @State var value:Training
    @State var remind:Bool; @State var time:Date
    init(model:AppModel,original:Training) { self.model=model; _value=State(initialValue:original); _remind=State(initialValue:original.reminder != nil); _time=State(initialValue:original.reminder ?? Day.date(original.day)!) }
    var body:some View { VStack(alignment:.leading,spacing:16) {
        Text("只修改 \(value.day)").font(.title2); TextField("名称",text:$value.name)
        Toggle("提醒",isOn:$remind); if remind { DatePicker("时间",selection:$time,displayedComponents:.hourAndMinute) }
        ScrollView { ForEach($value.exercises) { $e in ExercisePlanEditor(exercise:$e) } }.frame(height:250)
        Button("添加动作") { value.exercises.append(Exercise()) }
        HStack { Button("取消") { dismiss() };Spacer();Button("保存这一次") {
            let c=Calendar.current.dateComponents([.hour,.minute],from:time); value.reminder=remind ? Calendar.current.date(bySettingHour:c.hour!,minute:c.minute!,second:0,of:Day.date(value.day)!) : nil
            if model.change({ try $0.updateTraining(value) }) { dismiss() }
        }.buttonStyle(.borderedProminent) }
    }.padding(24).frame(width:580) }
}
struct TrainingLinks:View {
    @ObservedObject var model:AppModel; let day:String
    var body:some View { ForEach(model.library.trainings.filter { $0.day == day }) { t in
        HStack { Image(systemName:"dumbbell"); VStack(alignment:.leading) { Text(t.name); Text(t.status).font(.caption).foregroundStyle(.secondary) }; Spacer();Button("记录训练") { model.show("健身计划",day:day) }; if t.status != "已完成" && t.status != "已跳过" { Button("直接完成") { model.change { try $0.setTrainingStatus(t.id,"已完成") } } }
        }.padding(.vertical,8)
    } }
}
