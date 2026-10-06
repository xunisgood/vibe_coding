import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel
  var body: some View {
    NotificationSettings(notifications: model.notifications)
    Panel(title: "本地数据") {
      Text(model.store.file.path).font(.callout).textSelection(.enabled)
      Button("打开所在文件夹") { NSWorkspace.shared.activateFileViewerSelecting([model.store.file]) }
      Text("数据独立于应用保存，替换应用不会覆盖记录。").font(.caption).foregroundStyle(.secondary)
    }
    Panel(title: "备份与恢复") {
      Toggle(
        "每天自动备份，保留最近 7 份",
        isOn: Binding(
          get: { model.library.autoBackup }, set: { v in model.change { $0.autoBackup = v } }))
      Text(model.backups.directory(for: model.library).path).font(.caption).textSelection(.enabled)
      Text(model.backupStatus).font(.callout)
      HStack {
        Button("选择备份文件夹") { model.chooseBackupFolder() }
        Button("立即备份") { model.manualBackup() }
        Button("从备份恢复") { model.restoreBackup() }
      }
      Text("手动备份和恢复前备份不会自动删除。恢复会先检查完整性，再备份当前文件。").font(.caption).foregroundStyle(.secondary)
    }
  }
}

struct NotificationSettings: View {
  @ObservedObject var notifications: Notifications
  var body: some View {
    Panel(title: "主动提醒") {
      Text(notifications.permission)
      Text(notifications.status).font(.caption).foregroundStyle(.secondary)
      HStack {
        Button("允许通知") { notifications.request() }
        Button("系统通知设置") {
          NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
        }
        Button("10 秒后测试通知") { notifications.probe() }
      }
      if !notifications.probeStatus.isEmpty { Text(notifications.probeStatus).font(.caption) }
      Text("已登记的提醒由 macOS 交付；休眠、关机及专注模式可能延迟或隐藏通知。重复训练每次打开应用补充未来 45 天；请定期打开应用。登记不足会明确显示，不作为成功处理。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

struct SettingsWindowContent: View {
  @ObservedObject var model: AppModel
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("设置与数据").font(.system(size: 22, weight: .semibold))
        if let warning = model.workspaceWarning { Text(warning).foregroundStyle(.orange) }
        if model.dirty { Button("重试保存") { model.save() } }
        SettingsView(model: model)
      }.padding(24)
    }.background(LifeBackdrop()).controlSize(.regular)
      .alert(
        "需要处理",
        isPresented: Binding(
          get: { model.error != nil && NSApp.keyWindow?.title == "设置与数据" },
          set: { if !$0 { model.error = nil } })
      ) {
        Button("知道了") { model.error = nil }
      } message: {
        Text(model.error ?? "")
      }
  }
}
