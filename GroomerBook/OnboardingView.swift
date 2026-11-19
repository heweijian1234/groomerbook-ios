import SwiftUI

// MARK: - 新手引导（健哥 11-19 令：GroomerBook 加新手引导教程）
// 形态：首启全屏 4 步卡片（对应 4 个 tab 核心操作），可 Skip，看完/跳过都不再弹（UserDefaults 记忆）。
// 入口：①首次自动弹 ②反馈页(Me tab)底部"重看新手引导"。

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Step {
        let icon: String
        let color: Color
        let title: String
        let body: String
        let tip: String   // 底部一句话实操点
    }

    // 英文上架版（同 L() 机制：中文测试版走 zh 分支）
    private var steps: [Step] {
        let en = AppLang.current == .en
        return [
            Step(
                icon: "calendar",
                color: .orange,
                title: en ? "1 · Today — your day at a glance" : "1 · 今日——一天全貌",
                body: en
                    ? "Today's visits show address, phone, navigation and any special tools to bring. Mark a visit Done or No-show when it's finished."
                    : "今天的上门：地址、电话、导航、要带的特殊工具一目了然。完成或没成功点一下就记录。",
                tip: en ? "Tap a visit to edit it. Swipe left to delete." : "点预约行可编辑；左滑可删除。"
            ),
            Step(
                icon: "person.2",
                color: .blue,
                title: en ? "2 · Clients — people first" : "2 · 客户——先建人",
                body: en
                    ? "Add a client with phone, address and family contacts. You can add their pets right on the same screen — or link a registered pet that has no owner yet."
                    : "建客户：电话、地址、家人对接人。同一屏可顺便加宠物，也可以认领已登记的无主宠物。",
                tip: en ? "Open a client to see their pets and visit history." : "点进客户看TA的宠物和上门记录。"
            ),
            Step(
                icon: "pawprint",
                color: .green,
                title: en ? "3 · Pets — the details that matter" : "3 · 宠物——关键细节",
                body: en
                    ? "For each pet: bite risk, temperament, favorite treats, grooming recipe, special tools, vaccine expiry and a photo. Warnings show up automatically on every appointment."
                    : "每只宠物：咬人风险、脾气、爱吃啥、美容配方、特殊工具、疫苗到期、照片。警告会自动出现在每个预约上。",
                tip: en ? "The BITES / CARE badge is always visible in lists." : "咬人/谨慎标记在列表常驻可见。"
            ),
            Step(
                icon: "paperplane",
                color: .purple,
                title: en ? "4 · Book visits & get reminders" : "4 · 约单+闹钟提醒",
                body: en
                    ? "Tap + on Today to book a visit: pick the client, their pets, time, duration and up to 3 reminders. Everything stays on this phone — no account, no cloud."
                    : "今日页点 + 约单：选客户、宠物、时间、时长、最多3个闹钟。数据只在这台手机上——无账户无云端。",
                tip: en ? "Trouble or ideas? Tell us from the Me tab." : "有问题或想法？「我的」页直接反馈给开发者。"
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    stepCard(step, index: i)
                        .tag(i)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                Button {
                    onFinish()   // Skip
                } label: {
                    Text(L("Skip", "跳过"))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if page < steps.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < steps.count - 1 ? L("Next", "下一步") : L("Get Started", "开始使用"))
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.orange))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func stepCard(_ step: Step, index: Int) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: step.icon)
                .font(.system(size: 64))
                .foregroundColor(step.color)
                .padding(.bottom, 6)
            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(step.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Label(step.tip, systemImage: "lightbulb.max")
                .font(.footnote)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
            Spacer()
            Spacer()
        }
    }
}

// MARK: - 引导状态（首启判断）

enum Onboarding {
    private static let key = "groomerbook.onboarding.done"

    static var isDone: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markDone() {
        UserDefaults.standard.set(true, forKey: key)
    }

    /// 手动重看（反馈页入口）
    static func reset() {
        UserDefaults.standard.set(false, forKey: key)
    }
}
