import AppKit
import UserNotifications
import LifeCore
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: NSWindow!
    let status = NSTextField(wrappingLabelWithString: "等待测试")
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 360), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "我的日常 · 通知验证"
        let button = NSButton(title: "允许通知并在 10 秒后测试", target: self, action: #selector(testNotification))
        button.frame = NSRect(x: 150, y: 160, width: 350, height: 45)
        window.contentView?.addSubview(button)
        status.frame = NSRect(x: 40, y: 50, width: 570, height: 90); window.contentView?.addSubview(status)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            UNUserNotificationCenter.current().getDeliveredNotifications { items in
                if items.contains(where: { $0.request.identifier == "probe" }) { DispatchQueue.main.async { self.status.stringValue = "系统已交付 probe 通知（getDeliveredNotifications 已确认）" } }
            }
        }
    }
    @objc func testNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            DispatchQueue.main.async { self.status.stringValue = "授权：\(granted)，错误：\(String(describing: error))" }
            guard granted else { return }
            let content = UNMutableNotificationContent(); content.title = "我的日常"; content.body = "本地系统通知验证"; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "probe", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))) { error in DispatchQueue.main.async { self.status.stringValue = "登记结果：\(error?.localizedDescription ?? "成功")" } }
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { DispatchQueue.main.async { self.status.stringValue = "已收到系统前台通知回调" }; completionHandler([.banner, .sound]) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
}
let app = NSApplication.shared
let delegate = AppDelegate(); app.delegate = delegate
app.setActivationPolicy(.regular); app.run()
