import AppKit
import Foundation
import LifeCore
import SwiftUI

@MainActor final class AppModel: ObservableObject {
  @Published var newRequest = 0
  @Published var searchRequest = 0
  @Published var sidebarVisible = true {
    didSet { if oldValue != sidebarVisible { saveWorkspace() } }
  }
  @Published var sidebarWidth: Double = 200 {
    didSet { if oldValue != sidebarWidth { saveWorkspace() } }
  }
  var prepareToLeave: (() -> Bool)?
  func navigate(_ destination: String) {
    guard destination != page else { return }
    guard prepareToLeave?() ?? true else { return }
    page = destination
  }
  var openSettings: (() -> Void)?
  var newTitle: String? {
    [
      "今日计划": "新建待办", "笔记": "新建", "开发工作": "新建项目",
      "健身计划": "新建训练安排", "游戏娱乐": "记录游戏",
    ][page]
  }
  var canSearch: Bool { ["笔记", "游戏娱乐"].contains(page) }
  func requestNew() { if newTitle != nil && !locked { newRequest += 1 } }
  func requestSearch() { if canSearch { searchRequest += 1 } }
  @Published var library = Library()
  @Published var selectedNoteID: UUID? {
    didSet { if oldValue != selectedNoteID { saveWorkspace() } }
  }
  @Published var selectedProjectID: UUID? {
    didSet { if oldValue != selectedProjectID { saveWorkspace() } }
  }
  @Published var focusedReminderID: String?
  @Published var page = "首页总览" { didSet { if oldValue != page { saveWorkspace() } } }
  @Published var selectedDate = Date() {
    didSet { if oldValue != selectedDate { saveWorkspace() } }
  }
  @Published var status = "已保存"
  @Published var error: String?
  @Published var backupStatus = "尚无备份"
  @Published var locked = false
  @Published var dirty = false
  @Published var undoAvailable = false
  var undoAction: ((inout Library) -> Void)?
  @Published var workspaceWarning: String?
  private var workspaceReady = false
  var windowFrame: String?
  var workspaceFile: URL { store.directory.appendingPathComponent("workspace.json") }
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
      restoreWorkspace()
    } catch {
      locked = true
      status = "数据读取失败"
      self.error = "原文件已保留。请在设置中恢复备份。\n" + error.localizedDescription
    }
  }
  private func restoreWorkspace() {
    defer { workspaceReady = true }
    guard FileManager.default.fileExists(atPath: workspaceFile.path) else { return }
    do {
      let saved = try JSONDecoder().decode(
        WorkspaceState.self, from: Data(contentsOf: workspaceFile)
      ).validated(in: library)
      page = saved.page
      selectedNoteID = saved.noteID
      selectedProjectID = saved.projectID
      sidebarVisible = saved.sidebarVisible
      sidebarWidth = saved.sidebarWidth
      windowFrame = saved.windowFrame
      selectedDate =
        saved.followsToday ? Date() : saved.selectedDay.flatMap { Day.date($0) } ?? Date()
    } catch { workspaceWarning = "界面偏好无法读取，已使用默认布局；业务记录未受影响。" }
  }
  func saveWorkspace() {
    guard workspaceReady, lease != nil, !locked else { return }
    let state = WorkspaceState(
      page: page, noteID: selectedNoteID, projectID: selectedProjectID,
      sidebarVisible: sidebarVisible, sidebarWidth: sidebarWidth,
      selectedDay: day, followsToday: day == today, windowFrame: windowFrame)
    do {
      try store.atomicWrite(JSONEncoder().encode(state), to: workspaceFile)
      workspaceWarning = nil
    } catch { workspaceWarning = "界面偏好保存失败，业务记录仍按原有机制保存。" }
  }
  func recordWindowFrame(_ frame: NSRect) {
    let value = NSStringFromRect(frame)
    if windowFrame != value {
      windowFrame = value
      saveWorkspace()
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
    guard prepareToLeave?() ?? true else { return }
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
