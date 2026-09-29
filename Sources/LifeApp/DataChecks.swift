import AppKit
import Foundation
import LifeCore

@MainActor enum DataChecks {
  static func run(_ phase: String, output: URL) {
    var passed: [String] = []
    do {
      let root = output.deletingLastPathComponent()
      let dir = root.appendingPathComponent("isolated-data")
      let model = AppModel(directory: dir)
      let expected = root.appendingPathComponent("expected.json")
      func require(_ value: Bool, _ message: String) throws {
        if !value { throw LifeError(message) }
      }
      if phase == "seed" {
        try require(
          !FileManager.default.fileExists(atPath: model.store.file.path), "隔离测试目录已有数据，拒绝覆盖")
        let day = "2026-09-29"
        try require(
          model.change { l in
            l.todos = [Todo(title: "验收待办", day: day)]
            var n = Note()
            n.title = "学习记录"
            n.body = "虚构验收内容"
            l.notes = [n]
            let memo = Memo("转换为任务")
            l.memos = [memo]
            _ = try l.convertMemo(memo.id, to: "todo", day: day)
            var project = Project("验收项目")
            var entry = DevEntry()
            entry.title = "开发进展"
            entry.kind = "进展"
            entry.body = "仅用于本地测试"
            project.entries = [entry]
            l.projects = [project]
            var p = TrainingPlan()
            p.name = "验收训练"
            p.start = day
            p.once = day
            var e = Exercise()
            e.name = "深蹲"
            p.exercises = [e]
            l.plans = [p]
            l.materialize(from: day, through: day)
            var actual = SetRecord()
            actual.reps = 8
            actual.weight = 20
            actual.done = true
            l.trainings[0].exercises[0].sets = [actual]
            l.trainings[0].status = "进行中"
            var meal = Meal(day: day, slot: "午餐")
            meal.planned = "米饭"
            meal.actual = "米饭和蔬菜"
            meal.calories = 500
            l.meals = [meal]
            l.games = [Game(day: day, name: "验收游戏", minutes: 45)]
          }, "种子数据保存失败")
        try LibraryStore.encode(model.library).write(to: expected, options: .atomic)
        let backup = try model.backups.create(model.library)
        try backup.path.write(
          to: root.appendingPathComponent("backup-path.txt"), atomically: true, encoding: .utf8)
        passed.append("all-modules-saved-through-app-model")
      } else {
        let baseline = try LibraryStore.decode(Data(contentsOf: expected))
        try require(model.library == baseline, "跨进程读取不一致")
        passed.append("new-process-loaded-all-records-and-relations")
        if phase == "restore" {
          try require(
            model.change {
              $0.todos = []
              $0.games = []
            }, "准备恢复场景失败")
          let path = try String(
            contentsOf: root.appendingPathComponent("backup-path.txt"), encoding: .utf8)
          let restored = try model.backups.restore(
            URL(fileURLWithPath: path), current: model.library)
          try require(restored == baseline && model.store.load() == baseline, "恢复结果不一致")
          passed.append("full-backup-restore-preserves-every-module")
        } else {
          try require(phase == "read", "未知验证阶段")
        }
      }
      let result: [String: Any] = ["success": true, "phase": phase, "passed": passed]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    } catch {
      let result: [String: Any] = [
        "success": false, "phase": phase, "passed": passed, "error": error.localizedDescription,
      ]
      try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    }
    NSApp.terminate(nil)
  }
}
