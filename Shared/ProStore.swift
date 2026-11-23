import Foundation
import StoreKit
import UserNotifications   // 购买后撤掉"试用还剩2天"通知

// MARK: - Pro 买断（十资产报告③：$14.99 买断墙——付费墙位置=「趋势→洞察」边界）
// 原则（SOP S3 变现设计节）：免费层=基础记录+简单查看；Pro=数据资产导出（洞察/沉淀层）。
// 苹果内购非消耗品；老用户终身权益规则由苹果交易记录保障。

enum ProStore {
    static let productID = "com.zeronelabs.groomerbook.pro.lifetime"

    /// 是否已解锁（交易监听启动后自动更新）
    static var unlocked: Bool {
        UserDefaults.standard.bool(forKey: "groomerbook.pro.unlocked")
    }

    static func markUnlocked() {
        UserDefaults.standard.set(true, forKey: "groomerbook.pro.unlocked")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["groomerbook.trial.endsSoon"])
    }

    /// 购买（StoreKit 2）
    static func purchase() async -> Bool {
        guard let product = try? await Product.products(for: [productID]).first else {
            return false   // 商品没配好（ASC 内购商品未创建/未通过）
        }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()   // 11-24补：苹果要求完成交易，不然重复投递（finish是async，CI批注实锤）
                markUnlocked()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 启动时恢复购买（换机/重装场景）
    /// 🔴currentEntitlements元素=VerificationResult<Transaction>，必须解包再取productID（CI两轮红根因）
    static func restore() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == productID {
                markUnlocked()
                return
            }
        }
    }
}
