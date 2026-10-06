import AppKit
import LifeCore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSWindowDelegate {
  var window: NSWindow!
  var settingsWindow: NSWindow?
  private var restoringWindow = true
  var model: AppModel!
  var lastDay = Day.key(Date())
  var timer: Timer?
  func applicationDidFinishLaunching(_ notification: Notification) {
    let args = CommandLine.arguments
    // UI-test-only appearance override; never writes the user's system appearance preference.
    if Bundle.main.bundleIdentifier == "com.xunisgood.personallife.uitestapp",
      let index = args.firstIndex(of: "--ui-appearance"), args.count > index + 1
    {
      NSApp.appearance = NSAppearance(named: args[index + 1] == "dark" ? .darkAqua : .aqua)
    }
    if let index = args.firstIndex(of: "--native-check"), args.count > index + 2 {
      Task {
        await NativeChecks.run(args[index + 1], output: URL(fileURLWithPath: args[index + 2]))
      }
      return
    }
    if let index = args.firstIndex(of: "--data-check"), args.count > index + 2 {
      DataChecks.run(args[index + 1], output: URL(fileURLWithPath: args[index + 2]))
      return
    }
    if let index = args.firstIndex(of: "--data-directory"), args.count > index + 1 {
      model = AppModel(directory: URL(fileURLWithPath: args[index + 1], isDirectory: true))
    } else {
      model = AppModel()
    }
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
      styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false
    )
    window.delegate = self
    window.title = "我的日常"
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.backgroundColor = .windowBackgroundColor
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 880, height: 620)
    model.openSettings = { [weak self] in self?.showSettings() }
    if Bundle.main.bundleIdentifier == "com.xunisgood.personallife.uitestapp",
      args.contains("--ui-reduced-effects")
    {
      window.contentView = NSHostingView(
        rootView: RootView(model: model)
          .environment(\.lifeReducedEffects, true))
    } else {
      window.contentView = NSHostingView(rootView: RootView(model: model))
    }
    if let saved = model.windowFrame,
      let frame = WorkspaceState.fittedFrame(
        NSRectFromString(saved), screens: NSScreen.screens.map(\.visibleFrame))
    {
      window.setFrame(frame, display: false)
    } else {
      window.center()
    }
    window.makeKeyAndOrderFront(nil)
    restoringWindow = false
    model.recordWindowFrame(window.frame)
    let menu = NSMenu()
    let appItem = NSMenuItem()
    let submenu = NSMenu()
    submenu.addItem(
      withTitle: "退出我的日常", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = submenu
    menu.addItem(appItem)
    let edit = NSMenuItem()
    edit.title = "编辑"
    edit.submenu = NSMenu(title: "编辑")
    for (name, action, key) in [
      ("撤销", "undo:", "z"), ("重做", "redo:", "Z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"),
      ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a"),
    ] { edit.submenu?.addItem(withTitle: name, action: Selector(action), keyEquivalent: key) }
    menu.addItem(edit)
    let windowMenu = NSMenuItem()
    windowMenu.title = "窗口"
    windowMenu.submenu = NSMenu(title: "窗口")
    windowMenu.submenu?.addItem(
      withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    menu.addItem(windowMenu)
    let file = NSMenuItem()
    file.title = "文件"
    file.submenu = NSMenu(title: "文件")
    let new = NSMenuItem(title: "新建", action: #selector(newCurrent), keyEquivalent: "n")
    new.target = self
    file.submenu?.addItem(new)
    menu.insertItem(file, at: 1)
    let find = NSMenuItem(title: "查找…", action: #selector(findCurrent), keyEquivalent: "f")
    find.target = self
    edit.submenu?.addItem(find)
    let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
    settings.target = self
    submenu.insertItem(settings, at: 0)
    let view = NSMenuItem()
    view.title = "显示"
    view.submenu = NSMenu(title: "显示")
    let sidebar = NSMenuItem(title: "显示或隐藏导航", action: #selector(toggleSidebar), keyEquivalent: "s")
    sidebar.keyEquivalentModifierMask = [.command, .option]
    sidebar.target = self
    view.submenu?.addItem(sidebar)
    menu.insertItem(view, at: 3)
    NSApp.mainMenu = menu
    NSApp.activate(ignoringOtherApps: true)
    model.notifications.model = model
    model.notifications.openWindow = { [weak self] in
      self?.window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
    model.didEnableReminder = { [weak self] in self?.model.notifications.request() }
    model.didSave = { [weak self] in
      guard let self else { return }
      self.model.notifications.sync(self.model.library)
    }
    if !model.locked {
      var next = model.library
      let start = next.plans.map(\.start).min() ?? model.today
      next.materialize(from: start, through: Day.adding(45, to: model.today))
      if next != model.library { model.change { $0 = next } }
      model.notifications.sync(model.library)
    }
    timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        let today = Day.key(Date())
        if today != self.lastDay {
          if self.model.day == self.lastDay { self.model.selectedDate = Date() }
          self.lastDay = today
          self.model.ensureTrainings()
        }
        self.model.notifications.checkProbe()
        if !self.model.locked { self.model.notifications.sync(self.model.library) }
        self.model.objectWillChange.send()
      }
    }
  }
  @objc func newCurrent() { model.requestNew() }
  @objc func findCurrent() { model.requestSearch() }
  @objc func toggleSidebar() { model.sidebarVisible.toggle() }
  @objc func showSettings() {
    guard model.prepareToLeave?() ?? true else { return }
    if settingsWindow == nil {
      let panel = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 680, height: 660),
        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
      panel.title = "设置与数据"
      panel.isReleasedWhenClosed = false
      panel.minSize = NSSize(width: 600, height: 500)
      panel.contentView = NSHostingView(rootView: SettingsWindowContent(model: model))
      panel.center()
      settingsWindow = panel
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
  }
  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    let active = NSApp.keyWindow === window && window.attachedSheet == nil
    if item.action == #selector(showSettings) { return NSApp.keyWindow?.attachedSheet == nil }
    if item.action == #selector(newCurrent) {
      item.title = model.newTitle ?? "新建"
      return active && model.newTitle != nil && !model.locked
    }
    if item.action == #selector(findCurrent) { return active && model.canSearch }
    return active
  }
  func windowDidMove(_ notification: Notification) { rememberWindow(notification) }
  func windowDidResize(_ notification: Notification) { rememberWindow(notification) }
  private func rememberWindow(_ notification: Notification) {
    if !restoringWindow, let changed = notification.object as? NSWindow, changed === window,
      model != nil
    {
      model.recordWindowFrame(changed.frame)
    }
  }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender !== window || (model.prepareToLeave?() ?? true)
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    window.makeKeyAndOrderFront(nil)
    return true
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if model != nil && !(model.prepareToLeave?() ?? true) { return .terminateCancel }
    if model != nil && model.dirty && !model.save() { return .terminateCancel }
    return .terminateNow
  }
}
@main struct LifeApplication {
  @MainActor static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
    withExtendedLifetime(delegate) {}
  }
}
