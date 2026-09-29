import SwiftUI
import AppKit
struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Panel(title: "本地数据") {
            Text(model.store.file.path).font(.callout).textSelection(.enabled)
            Button("打开所在文件夹") { NSWorkspace.shared.activateFileViewerSelecting([model.store.file]) }
            Text("数据独立于应用保存，替换应用不会覆盖记录。").font(.caption).foregroundStyle(.secondary)
        }
        Panel(title: "备份与恢复") {
            Toggle("每天自动备份，保留最近 7 份", isOn: Binding(get: { model.library.autoBackup }, set: { v in model.change { $0.autoBackup = v } }))
            Text(model.backups.directory(for: model.library).path).font(.caption).textSelection(.enabled)
            Text(model.backupStatus).font(.callout)
            HStack { Button("选择备份文件夹") { model.chooseBackupFolder() }; Button("立即备份") { model.manualBackup() }; Button("从备份恢复") { model.restoreBackup() } }
            Text("手动备份和恢复前备份不会自动删除。恢复会先检查完整性，再备份当前文件。").font(.caption).foregroundStyle(.secondary)
        }
    }
}
