import Foundation
import AppKit
import UserNotifications
import LifeCore

@MainActor final class Notifications:NSObject,ObservableObject,UNUserNotificationCenterDelegate {
    @Published var permission="正在读取通知权限"
    @Published var status=""
    @Published var probeStatus=""
    weak var model:AppModel?
    var openWindow:(()->Void)?
    private var latest:Library?
    private var running=false
    private var revision=0
    private let center=UNUserNotificationCenter.current()
    override init() { super.init();center.delegate=self }
    func refreshPermission() async -> Bool {
        let s=await center.notificationSettings()
        let allowed=s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
        switch s.authorizationStatus { case .notDetermined:permission="尚未授权";case .denied:permission="系统通知已关闭，请到系统设置开启";default:permission=allowed ? "通知已允许" : "通知不可用" }
        return allowed
    }
    func request() { Task {
        do { _=try await center.requestAuthorization(options:[.alert,.sound]);if await refreshPermission(),let model { sync(model.library) } }
        catch { status="授权失败："+error.localizedDescription }
    } }
    func sync(_ library:Library) {
        latest=library;revision+=1
        guard !running else { return };running=true
        Task {
            repeat {
                let currentRevision=revision
                if let snapshot=latest { await reconcile(snapshot) }
                if currentRevision == revision { break }
            } while true
            running=false
        }
    }
    private func reconcile(_ library:Library) async {
        let allowed=await refreshPermission()
        let desired=allowed ? library.futureReminders(now:Date()) : []
        let pending=await center.pendingNotificationRequests();let ids=Set(desired.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers:pending.filter { $0.identifier.hasPrefix("life.") && !ids.contains($0.identifier) }.map(\.identifier))
        let delivered=await center.deliveredNotifications()
        let active=Set(library.reminders().map(\.id))
        center.removeDeliveredNotifications(withIdentifiers:delivered.filter { $0.request.identifier.hasPrefix("life.") && !active.contains($0.request.identifier) }.map { $0.request.identifier })
        guard allowed else { status="记录已保存，但系统通知未启用";return }
        var failures:[String]=[]
        for r in desired {
            if let old=pending.first(where:{ $0.identifier == r.id }), old.content.title == r.title, (old.content.userInfo["time"] as? Double) == r.date.timeIntervalSince1970 { continue }
            let c=UNMutableNotificationContent();c.title=r.title;c.body=r.page+" · "+r.day;c.sound = .default;c.userInfo=["page":r.page,"day":r.day,"time":r.date.timeIntervalSince1970]
            let components=Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second],from:r.date)
            do { try await center.add(UNNotificationRequest(identifier:r.id,content:c,trigger:UNCalendarNotificationTrigger(dateMatching:components,repeats:false))) }
            catch { failures.append(r.title+"："+error.localizedDescription) }
        }
        let registered=Set(await center.pendingNotificationRequests().map(\.identifier))
        let missing=desired.filter { $0.date > Date() && !registered.contains($0.id) }
        status=failures.isEmpty && missing.isEmpty ? "已登记 \(desired.count) 条未来提醒" : "部分提醒未登记（\(missing.count) 条）："+failures.joined(separator:"；")
    }
    func probe() { Task {
        guard await refreshPermission() else { request();return }
        let c=UNMutableNotificationContent();c.title="我的日常 · 通知测试";c.body="这是真实 macOS 本地通知";c.sound = .default
        do { try await center.add(UNNotificationRequest(identifier:"probe",content:c,trigger:UNTimeIntervalNotificationTrigger(timeInterval:10,repeats:false)));probeStatus="测试已登记，10 秒后触发" }
        catch { probeStatus=error.localizedDescription }
    } }
    func checkProbe() { Task { let list=await center.deliveredNotifications();if list.contains(where:{ $0.request.identifier == "probe" }) { probeStatus="系统已确认交付测试通知" } } }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping(UNNotificationPresentationOptions)->Void) { completionHandler([.banner,.sound,.list]) }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping()->Void) {
        let id=response.notification.request.identifier
        Task { @MainActor in
            self.openWindow?()
            if id == "probe" { self.model?.page="设置与数据";self.probeStatus="点击通知已打开应用" }
            else if let r=self.model?.library.reminders().first(where:{ $0.id == id }) {
                self.model?.show(r.page,day:r.day);self.model?.focusedReminderID=id
            } else { self.model?.error="对应事项已完成或已删除。" }
            completionHandler()
        }
    }
}
struct NotificationRoute {
    static func target(_ id:String) -> String { id.hasPrefix("life.training.") ? "健身计划" : "今日计划" }
}
