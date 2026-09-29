import AppKit
import Foundation
import UserNotifications

@MainActor enum NativeChecks {
  static func run(_ phase: String, output: URL) async {
    let center = UNUserNotificationCenter.current()
    var passed: [String] = []
    do {
      let settings = await center.notificationSettings()
      guard settings.authorizationStatus == .authorized else {
        throw NSError(
          domain: "NativeChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "通知权限未允许"])
      }
      passed.append("system-permission-authorized")
      func request(_ id: String, _ title: String, _ delay: Double) -> UNNotificationRequest {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = "我的日常 · 自动验收通知"
        c.sound = .default
        return UNNotificationRequest(
          identifier: id, content: c,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false))
      }
      func require(_ condition: Bool, _ message: String) throws {
        if !condition {
          throw NSError(
            domain: "NativeChecks", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
      }
      if phase == "schedule" {
        center.removeDeliveredNotifications(withIdentifiers: ["verify.delivery"])
        try await center.add(request("verify.replace", "旧提醒", 300))
        try await center.add(request("verify.replace", "新提醒", 400))
        let replaced = await center.pendingNotificationRequests().filter {
          $0.identifier == "verify.replace"
        }
        try require(replaced.count == 1 && replaced[0].content.title == "新提醒", "替换未生效")
        passed.append("same-id-replaces-old-request")
        center.removePendingNotificationRequests(withIdentifiers: ["verify.replace"])
        let cancelled = await center.pendingNotificationRequests()
        try require(!cancelled.contains { $0.identifier == "verify.replace" }, "取消未生效")
        passed.append("cancel-removes-request")
        try await center.add(request("verify.delivery", "我的日常 · 退出后通知验证", 10))
        let pending = await center.pendingNotificationRequests()
        try require(pending.contains { $0.identifier == "verify.delivery" }, "未登记交付测试")
        passed.append("delivery-test-registered-before-exit")
      } else if phase == "inspect" {
        let delivered = await center.deliveredNotifications()
        try require(delivered.contains { $0.request.identifier == "verify.delivery" }, "系统未交付退出后通知")
        passed.append("system-delivered-while-app-exited")
        center.removeDeliveredNotifications(withIdentifiers: ["verify.delivery"])
      } else {
        try require(false, "未知验证阶段")
      }
      let result: [String: Any] = [
        "phase": phase, "passed": passed, "success": true, "timestamp": Date().description,
      ]
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    } catch {
      let result: [String: Any] = [
        "phase": phase, "passed": passed, "success": false, "error": error.localizedDescription,
      ]
      try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    }
    NSApp.terminate(nil)
  }
}
