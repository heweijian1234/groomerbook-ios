import Foundation

// MARK: - 双语切换（2026-11-08 上架令：英文上架版；中文测试版历史保留——切换此枚举即回中文）
// 机制：全部 UI 字符串经 L() 取值；上架=en。之后若做本地化多语言，换 Locale 判断即可。

enum AppLang {
    case en
    case zh

    static let current: AppLang = .en   // 🔴上架版=英文（健哥 2026-11-08 令）。中文测试版改回 .zh
}

func L(_ en: String, _ zh: String) -> String {
    AppLang.current == .en ? en : zh
}

// MARK: - 带参数的复合句（避免调用处拼中英混串）

enum L10n {
    /// "有 N 次没成功记录——建议收押金"
    static func noShowWarn(_ count: Int) -> String {
        AppLang.current == .en
            ? "\(count) no-show\(count > 1 ? "s" : "") on record — consider a deposit"
            : "有 \(count) 次没成功记录——建议收押金"
    }

    /// "带：工具1；工具2"
    static func toolsNeeded(_ tools: [String]) -> String {
        let joined = tools.joined(separator: AppLang.current == .en ? "; " : "；")
        return AppLang.current == .en ? "Bring: \(joined)" : "带：\(joined)"
    }

    /// "已准备：xxx"
    static func preparedNote(_ notes: String) -> String {
        AppLang.current == .en ? "Prepared: \(notes)" : "已准备：\(notes)"
    }

    /// "提前X提醒"（预约卡蓝标）
    static func remindLabel(_ minutesList: [Int]) -> String {
        let sorted = minutesList.sorted().map { mins in
            mins >= 60
                ? (AppLang.current == .en ? "\(mins / 60)h before" : "提前\(mins / 60)小时")
                : (AppLang.current == .en ? "\(mins) min before" : "提前\(mins)分钟")
        }
        let sep = AppLang.current == .en ? ", " : "、"
        let tail = AppLang.current == .en ? " reminder" : "提醒"
        return sorted.joined(separator: sep) + tail
    }

    /// "距上次美容 N 天"
    static func daysSinceLast(_ days: Int) -> String {
        AppLang.current == .en ? "\(days) days since last groom" : "距上次美容 \(days) 天"
    }

    /// "宠物（N）" / "上门记录（N）" 式计数标题
    static func countHeader(_ zh: String, _ en: String, _ count: Int) -> String {
        AppLang.current == .en ? "\(en) (\(count))" : "\(zh)（\(count)）"
    }
}
