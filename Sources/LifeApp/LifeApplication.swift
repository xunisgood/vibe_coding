import AppKit
import SwiftUI
import UserNotifications
import LifeCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!; var model: AppModel!
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled,.closable,.resizable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "我的日常"; window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 880, height: 620)
        window.contentView = NSHostingView(rootView: RootView(model: model)); window.center(); window.makeKeyAndOrderFront(nil)
        let menu = NSMenu(); let appItem = NSMenuItem(); let submenu = NSMenu(); submenu.addItem(withTitle: "退出我的日常", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = submenu; menu.addItem(appItem)
        let edit = NSMenuItem(); edit.title = "编辑"; edit.submenu = NSMenu(title: "编辑")
        for (name, action, key) in [("剪切", "cut:", "x"),("复制", "copy:", "c"),("粘贴", "paste:", "v"),("全选", "selectAll:", "a")] { edit.submenu?.addItem(withTitle: name, action: Selector(action), keyEquivalent: key) }; menu.addItem(edit); NSApp.mainMenu = menu
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model.dirty && !model.save() { return .terminateCancel }; return .terminateNow
    }
}
@main struct LifeApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
        withExtendedLifetime(delegate) {}
    }
}
