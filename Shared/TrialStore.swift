import Foundation
import UserNotifications   // F：到期前2天本地通知（把悬崖变缓坡）

// MARK: - 30天试用→买断 限时锁（2026-11-24 健哥拍板，决策日记第29条）
// 模型：30天全功能免费试用 → $14.99买断。到期=只读+导出免费+锁新建（不做硬锁，防悬崖差评）。
// 依据：G核心价值第一周兑现（短周期）→试用成立；第30天数据资产已攒=付费时刻（免费开局三条件①）。
// 重装=数据丢失+试用重置，但重置须清空自己生意记录，真用户不会干（漏洞自堵，不防）。

enum TrialStore {
    static let trialDays = 30
    private static let startKey = "groomerbook.trial.start"
    private static let overrideKey = "groomerbook.trial.debugOverride"   // 测试钩子（Me页版本行连点5下唤出）

    /// 全局付费墙弹出口——任何写入口被拦都发这个通知，RootView 统一接（避免每个子视图挂sheet）
    static let showPaywallNotification = Notification.Name("groomerbook.showProPaywall")

    /// 首启登记试用起点（升级用户=升级后首启起算）
    static func registerStartIfNeeded() {
        if UserDefaults.standard.object(forKey: startKey) == nil {
            let start = Date()
            UserDefaults.standard.set(start, forKey: startKey)
            scheduleEndsSoonReminder(from: start)
        }
    }

    /// F：到期前2天提醒（坏消息放事前；已购买会在markUnlocked里撤掉）
    private static func scheduleEndsSoonReminder(from start: Date) {
        guard let fire = Calendar.current.date(byAdding: .day, value: trialDays - 2, to: start) else { return }
        let content = UNMutableNotificationContent()
        content.title = L("Trial ends in 2 days", "试用还剩2天")
        content.body = L("Your records stay readable & exportable free forever. Unlock once to keep booking.",
                         "到期后记录仍可随便看、免费导出。解锁一次即可继续约单。")
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let req = UNNotificationRequest(identifier: "groomerbook.trial.endsSoon",
                                        content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        UNUserNotificationCenter.current().add(req)
    }

    static var startDate: Date? {
        UserDefaults.standard.object(forKey: startKey) as? Date
    }

    /// 测试覆盖：fresh=全新试用 / expired=强制到期 / unlocked=强制已购（仅测试钩子可设）
    static var debugOverride: String? {
        UserDefaults.standard.string(forKey: overrideKey)
    }
    static func setDebugOverride(_ v: String?) {
        if let v { UserDefaults.standard.set(v, forKey: overrideKey) }
        else { UserDefaults.standard.removeObject(forKey: overrideKey) }
    }

    /// 剩余天数（按自然日算，首启当天=第0天剩30）
    static var daysLeft: Int {
        if debugOverride == "expired" { return 0 }
        if debugOverride == "fresh" { return trialDays }
        guard let start = startDate else { return trialDays }
        let used = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return max(0, trialDays - used)
    }

    /// 是否可写（新建/编辑/删除/完成/没来全算写）
    static var canWrite: Bool {
        if debugOverride == "expired" { return false }
        if debugOverride == "fresh" || debugOverride == "unlocked" { return true }
        return ProStore.unlocked || daysLeft > 0
    }

    /// 写入口闸门：可写→true放行；到期→弹全局付费墙+false拦截
    static func gate() -> Bool {
        if canWrite { return true }
        NotificationCenter.default.post(name: showPaywallNotification, object: nil)
        return false
    }

    /// Me页状态行文案
    static var statusText: String {
        if ProStore.unlocked || debugOverride == "unlocked" {
            return L("Unlocked — lifetime", "已解锁 · 终身")
        }
        if canWrite {
            return L("Trial: \(daysLeft) days left", "试用中 · 剩 \(daysLeft) 天")
        }
        return L("Trial ended — read-only", "试用已结束 · 只读")
    }
}
