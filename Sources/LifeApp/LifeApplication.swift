import AppKit
import LifeCore
import SwiftUI
import UserNotifications

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
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
    window.title = "我的日常"
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.backgroundColor = .windowBackgroundColor
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 880, height: 620)
    window.contentView = NSHostingView(rootView: RootView(model: model))
    window.center()
    window.makeKeyAndOrderFront(nil)
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
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    window.makeKeyAndOrderFront(nil)
    return true
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
