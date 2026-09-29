import AppKit
import Foundation
import LifeCore
import SwiftUI

@MainActor final class AppModel: ObservableObject {
  @Published var library = Library()
  @Published var selectedProjectID: UUID?
  @Published var focusedReminderID: String?
  @Published var page = "首页总览"
  @Published var selectedDate = Date()
  @Published var status = "已保存"
  @Published var error: String?
  @Published var backupStatus = "尚无备份"
  @Published var locked = false
  @Published var dirty = false
  @Published var undoAvailable = false
  var undoAction: ((inout Library) -> Void)?
  private var lease: DataLease?
  let store: LibraryStore
  lazy var notifications = Notifications()
  var didSave: (() -> Void)?
  var didEnableReminder: (() -> Void)?
  private var savedHasReminders = false
  var today: String { Day.key(Date()) }
  var day: String { Day.key(selectedDate) }
  init(directory: URL = LibraryStore.defaultDirectory()) {
    store = LibraryStore(directory: directory)
    do {
      lease = try DataLease(directory: directory)
      library = try store.load()
      savedHasReminders = !library.reminders().isEmpty
      backupStatus = backups.latest(library).map { "最近备份：" + $0.formatted() } ?? "尚无有效备份"
    } catch {
      locked = true
      status = "数据读取失败"
      self.error = "原文件已保留。请在设置中恢复备份。\n" + error.localizedDescription
    }
  }
  @discardableResult func change(_ action: (inout Library) throws -> Void) -> Bool {
    guard !locked else {
      error = "数据文件无法读取，普通写入已锁定。请先恢复备份。"
      return false
    }
    do {
      var next = library
      try action(&next)
      try next.validate()
      library = next
      dirty = true
      return save()
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }
  @discardableResult func save() -> Bool {
    guard !locked else { return false }
    status = "保存中"
    do {
      try store.save(library)
      dirty = false
      status = "已保存"
      backupAutomatically()
      let hasReminders = !library.reminders().isEmpty
      let needsAuthorization = !savedHasReminders && hasReminders
      savedHasReminders = hasReminders
      didSave?()
      if needsAuthorization { didEnableReminder?() }
      return true
    } catch {
      dirty = true
      status = "保存失败 · 内容仍保留，请重试"
      self.error = error.localizedDescription
      return false
    }
  }
  func delete(_ action: (inout Library) -> Void, undo: @escaping (inout Library) -> Void) {
    let before = library
    _ = change(action)
    if library != before {
      undoAction = undo
      undoAvailable = true
    }
  }
  func undo() {
    guard let action = undoAction else { return }
    let before = library
    let saved = change(action)
    if saved || library != before {
      undoAction = nil
      undoAvailable = false
    }
  }
  func ensureTrainings() {
    guard !locked else { return }
    var next = library
    next.materialize(from: min(day, today), through: Day.adding(45, to: max(day, today)))
    if next != library { change { $0 = next } }
  }
  var backups: BackupService { BackupService(store: store) }
  func backupAutomatically() {
    do {
      try backups.automatic(library)
      backupStatus = backups.latest(library).map { "最近备份：" + $0.formatted() } ?? "尚无备份"
    } catch { backupStatus = "自动备份失败：" + error.localizedDescription }
  }
  func chooseBackupFolder() {
    let p = NSOpenPanel()
    p.canChooseDirectories = true
    p.canChooseFiles = false
    p.canCreateDirectories = true
    if p.runModal() == .OK, let url = p.url { change { $0.backupPath = url.path } }
  }
  func manualBackup() {
    guard !locked else {
      error = "原文件损坏，请先恢复。"
      return
    }
    guard !dirty || save() else { return }
    do {
      let url = try backups.create(library)
      backupStatus = "备份成功：" + url.lastPathComponent
      NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch { self.error = error.localizedDescription }
  }
  func restoreBackup() {
    guard lease != nil else {
      error = "无法独占访问数据目录，请关闭其他应用实例后重试。"
      return
    }
    guard !dirty || save() else { return }
    let p = NSOpenPanel()
    p.canChooseDirectories = false
    p.allowsMultipleSelection = false
    guard p.runModal() == .OK, let url = p.url else { return }
    do {
      let b = try backups.inspect(url)
      guard
        confirm(
          "恢复备份？", detail: "备份时间：\(b.created.formatted())\n文件：\(url.path)\n将替换全部记录，操作前自动保留当前数据。")
      else { return }
      library = try backups.restore(url, current: library)
      locked = false
      dirty = false
      undoAction = nil
      undoAvailable = false
      savedHasReminders = !library.reminders().isEmpty
      status = "已恢复"
      backupStatus = backups.latest(library).map { "最近备份：" + $0.formatted() } ?? "尚无有效备份"
      didSave?()
    } catch { self.error = error.localizedDescription }
  }
  func openReminder(_ id: String) {
    guard let reminder = library.reminders().first(where: { $0.id == id }) else {
      focusedReminderID = nil
      error = "对应事项已完成或已删除。"
      return
    }
    error = nil
    show(reminder.page, day: reminder.day)
    focusedReminderID = id
  }
  func show(_ page: String, day: String? = nil) {
    focusedReminderID = nil
    self.page = page
    if let day, let d = Day.date(day) { selectedDate = d }
  }
  func confirm(_ title: String, detail: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = detail
    alert.alertStyle = .warning
    alert.addButton(withTitle: "确认")
    alert.addButton(withTitle: "取消")
    return alert.runModal() == .alertFirstButtonReturn
  }
}
