import SwiftUI
import Combine   // 11-24试用制：NotificationCenter.publisher（全局付费墙通知）
import UserNotifications

@main
struct GroomerBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // 健哥令⑩：闹钟提醒——申请通知权限
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
        }
    }
}

// MARK: - 本地通知（健哥令⑩：预约闹钟；11-20令⑤：三种自由时间闹钟，锁屏显示闹钟名）

enum ReminderScheduler {
    /// 三闹钟调度（健哥11-20令⑤：开始准备/最晚出发/结束提醒——用户自由设时间点）
    static func schedule(appointment: Appointment, ownerName: String, petNames: String) {
        let center = UNUserNotificationCenter.current()
        cancel(appointmentId: appointment.id)
        guard appointment.status == .scheduled else { return }

        // (闹钟时间, 锁屏标题, 正文)——时间全 Optional（没开=不排）
        let alarms: [(date: Date?, title: String, body: String)] = [
            (appointment.prepAlarm,
             L("Start-prep reminder", "准备出发提醒"),
             L("Time to pack tools for \(ownerName)'s visit (\(petNames)).", "收拾工具出发——今天要去 \(ownerName) 家（\(petNames)）。")),
            (appointment.departAlarm,
             L("Latest departure", "最晚出发时间"),
             L("Leave now to make \(ownerName)'s appointment (\(petNames)).", "现在出发刚好赶上 \(ownerName) 的预约（\(petNames)）。")),
            (appointment.endAlarm,
             L("Service ending", "提醒结束时间"),
             L("Expected finish for \(ownerName)'s visit (\(petNames)).", "\(ownerName) 的预约预计这时结束（\(petNames)）。")),
        ]
        for (idx, alarm) in alarms.enumerated() {
            guard let d = alarm.date, d > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = alarm.title
            content.body = alarm.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(appointment.id.uuidString)-\(idx)", content: content, trigger: trigger))
        }
    }

    static func cancel(appointmentId: UUID) {
        // 清掉全部带序号 identifier（新旧两代闹钟同前缀）
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let ids = pending.map { $0.identifier }.filter { $0.hasPrefix(appointmentId.uuidString) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

// MARK: - 根视图 v3（今日/客户/宠物/我的）

struct RootView: View {
    @State private var data = Store.load()
    @State private var tab = 0
    // 健哥 11-19 令：新手引导——首启自动弹
    // 健哥 11-20 令①：只对真·首次安装弹——老设备（装过任意版本）升级后不再轰炸；
    // 引导没走完的老用户也不再每次进都弹（想看=Me页"重看新手引导"）
    @State private var showOnboarding = !Onboarding.isDone && !UserDefaults.standard.bool(forKey: "groomerbook.everLaunched")
    // 11-24试用制：全局付费墙（各写入口 TrialStore.gate() 拦截后发通知，这里统一弹）
    @State private var showProPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // 11-24试用制：到期只读横幅（坏消息放事前——记录还在、导出免费、解锁继续记）
            if !TrialStore.canWrite {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text(L("Trial ended — records are read-only. Export stays free.", "试用已结束——记录只读，导出仍免费。"))
                        .font(.caption)
                    Spacer()
                    Button(L("Unlock", "解锁")) {
                        NotificationCenter.default.post(name: TrialStore.showPaywallNotification, object: nil)
                    }
                    .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.orange)
            }
            // 🔴S7.9 标配（2026-11-28 健哥令）：左右滑切换页面——.page 翻页样式+自绘底部导航条（NotaryTrack f88d42d 范本）
            TabView(selection: $tab) {
                TodayView(data: $data).tag(0)
                ClientListView(data: $data).tag(1)
                FeedbackView(replayOnboarding: {
                    showOnboarding = true
                }, onBack: {
                    tab = 0   // 健哥11-21令②：右上角返回=切回今日页
                }).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 0) {
                tabBarButton(icon: "calendar", label: L("Today", "今日"), idx: 0)
                tabBarButton(icon: "person.2", label: L("Clients", "客户"), idx: 1)
                tabBarButton(icon: "person.crop.circle", label: L("Me", "我的"), idx: 2)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .background(.bar)
        }
        .onAppear {
            data = Store.load()
            // 健哥11-20令①：启动即记"装过"——下次进（含升级后）不再自动弹引导
            UserDefaults.standard.set(true, forKey: "groomerbook.everLaunched")
            TrialStore.registerStartIfNeeded()   // 11-24试用制：首启登记试用起点
            Task { await ProStore.restore() }    // 启动恢复购买（换机/重装场景）
        }
        .onReceive(NotificationCenter.default.publisher(for: TrialStore.showPaywallNotification)) { _ in
            showProPaywall = true
        }
        .sheet(isPresented: $showProPaywall) {
            ProPaywallView()
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: { Onboarding.markDone() }) {
            OnboardingView(onFinish: {
                Onboarding.markDone()
                showOnboarding = false
            })
        }
    }

    /// 🔴S7.9 标配：自绘底部导航按钮（滑动切页配对件）
    private func tabBarButton(icon: String, label: String, idx: Int) -> some View {
        Button {
            withAnimation { tab = idx }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(tab == idx ? .orange : .secondary)
        }
    }
}

// MARK: - Tab1 今日

struct TodayView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false
    @State private var editingAppt: Appointment?   // 健哥令第五轮①：点行进编辑

    /// 该约了
    var dueSoon: [(Pet, Int)] {
        let today = Calendar.current.startOfDay(for: Date())
        var result: [(Pet, Int)] = []
        for pet in data.pets where pet.status == .normal {
            let doneDays = data.appointments
                .filter { $0.ownerId == pet.ownerId && $0.status == .done }
                .compactMap { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0.date), to: today).day }
            let hasOpen = data.appointments.contains { $0.ownerId == pet.ownerId && $0.status == .scheduled }
            if let last = doneDays.min(), last >= Appointment.reorderDays - 7, !hasOpen {
                result.append((pet, last))
            }
        }
        return result.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.appointments.isEmpty && data.pets.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "scissors")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text(L("Your mobile grooming book", "你的移动美容台账"))
                            .font(.headline)
                        Text(L("Add a client first, then book your first visit. Everything stays on this phone.", "先加客户（含宠物），然后约第一单。所有数据只留在这台手机上。"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(todayAppointments) { appt in
                            if let owner = data.owners.first(where: { $0.id == appt.ownerId }) {
                                TodayVisitCard(appt: appt, owner: owner, data: $data, editingAppt: $editingAppt)
                            }
                        }
                        if !dueSoon.isEmpty {
                            Section(L("Due for rebooking", "该约了")) {
                                ForEach(dueSoon, id: \.0.id) { pet, days in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(pet.type.emoji) \(pet.name)").font(.headline)
                                            Text(L10n.daysSinceLast(days))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        ForEach(groupedByDay, id: \.0) { day, appts in
                            Section(day) {
                                ForEach(appts) { appt in
                                    // 健哥令第五轮①：左滑删除 + 点行进编辑（在路上短信已删，换成编辑）
                                    Button {
                                        if TrialStore.gate() { editingAppt = appt }   // 11-24试用制：到期锁编辑
                                    } label: {
                                        AppointmentRow(appt: appt, data: $data)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { offsets in
                                    guard TrialStore.gate() else { return }   // 11-24试用制：到期锁删除
                                    for i in offsets {
                                        ReminderScheduler.cancel(appointmentId: appts[i].id)
                                        data.appointments.removeAll { $0.id == appts[i].id }
                                    }
                                    Store.save(data)
                                }
                            }
                        }
                        if data.appointments.isEmpty && !data.owners.isEmpty {
                            Text(L("No appointments yet — tap + to add.", "还没有预约——点右上角添加。"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L("Today", "今日"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { if TrialStore.gate() { showAdd = true } } label: { Image(systemName: "plus") }   // 11-24试用制：到期锁新建
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                AppointmentEditor(data: $data, preselectedOwnerId: nil)
            }
            // 健哥令第五轮①：点已有预约→编辑器带原值
            .sheet(item: $editingAppt, onDismiss: { data = Store.load() }) { appt in
                AppointmentEditor(data: $data, preselectedOwnerId: nil, editing: appt)
            }
        }
    }

    var todayAppointments: [Appointment] {
        let cal = Calendar.current
        return data.appointments.filter { $0.status == .scheduled && cal.isDateInToday($0.date) }
    }

    private var groupedByDay: [(String, [Appointment])] {
        let df = DateFormatter()
        // 第七轮②：语言统一——英文版走英文 locale（"Nov 20 Friday"），中文测试版保留中文
        if AppLang.current == .en {
            df.dateFormat = "MMM d EEEE"
            df.locale = Locale(identifier: "en_US")
        } else {
            df.dateFormat = "M月d日 EEEE"
            df.locale = Locale(identifier: "zh_CN")
        }
        let groups = Dictionary(grouping: data.appointments.filter { $0.status == .scheduled }.sorted { $0.date < $1.date }) {
            df.string(from: $0.date)
        }
        return groups.sorted { $0.value.first!.date < $1.value.first!.date }
    }
}

// MARK: - 今日上门卡（地址/拨号/导航/短信/工具提醒）

struct TodayVisitCard: View {
    let appt: Appointment
    let owner: Owner
    @Binding var data: Store.Data
    @Binding var editingAppt: Appointment?   // 健哥令第五轮①：编辑入口

    var pets: [Pet] { appt.petIds.compactMap { id in data.pets.first { $0.id == id } } }
    var petNames: String { pets.isEmpty ? "" : pets.map { "\($0.type.emoji)\($0.name)" }.joined(separator: " ") }
    /// 特殊工具汇总（健哥令⑧前版：避免忘带）
    var toolsNeeded: [String] {
        pets.map { $0.specialTools }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("📍 Today's visit", "📍 今天上门")).font(.headline)
                Spacer()
                Text(appt.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            if !petNames.isEmpty {
                Text("\(petNames) · \(appt.groomMinutes) " + L("min", "分钟")).font(.caption).foregroundColor(.secondary)
            }
            if !owner.address.isEmpty {
                HStack {
                    Text(owner.address).font(.subheadline)
                    Spacer()
                    Button {
                        let q = owner.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "maps://?daddr=\(q)&dirflg=d") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(L("Navigate", "导航"), systemImage: "map.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if !owner.phone.isEmpty {
                HStack {
                    Text(owner.phone).font(.subheadline).monospacedDigit()
                    Spacer()
                    Button {
                        if let url = URL(string: "tel://\(owner.phone.filter { !$0.isWhitespace && $0 != "-" })") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(L("Call", "拨打"), systemImage: "phone.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !toolsNeeded.isEmpty {
                Label(L10n.toolsNeeded(toolsNeeded), systemImage: "suitcase.cart")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            // 健哥令第七轮⑥：今日卡也带注意事项（客户备注/宠物脾气咬人/预约备注）
            if !owner.notes.isEmpty {
                Label(L("Client note", "客户备注") + ": " + owner.notes, systemImage: "person.crop.square.and.at.rectangle")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            ForEach(pets, id: \.id) { p in
                let bits: [String] = [
                    p.biteLevel == 2 ? L("BITES", "咬人") : nil,
                    p.biteLevel == 1 ? L("handle with care", "谨慎") : nil,
                    p.temperament.isEmpty ? nil : p.temperament,
                    p.status == .sick ? L("sick", "生病中") : nil
                ].compactMap { $0 }
                if !bits.isEmpty {
                    Label("\(p.type.emoji)\(p.name): " + bits.joined(separator: " · "), systemImage: "pawprint")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if !appt.note.isEmpty {
                Label(appt.note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            // 健哥令第五轮①：在路上短信已删——换编辑入口
            HStack {
                Spacer()
                Button {
                    if TrialStore.gate() { editingAppt = appt }   // 11-24试用制：到期锁编辑
                } label: {
                    Label(L("Edit", "编辑此单"), systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预约行

struct AppointmentRow: View {
    let appt: Appointment
    @Binding var data: Store.Data

    var owner: Owner? { data.owners.first { $0.id == appt.ownerId } }
    var pets: [Pet] { appt.petIds.compactMap { id in data.pets.first { $0.id == id } } }

    var noShowWarn: String? {
        guard let owner else { return nil }
        let petCount = pets.reduce(0) { $0 + $1.noShowCount }
        return (owner.noShowCount + petCount) > 0 ? L10n.noShowWarn(owner.noShowCount + petCount) : nil
    }

    /// 健哥令第七轮⑥：订单注意事项聚合——客户备注/宠物注意事项/特殊工具
    var clientNote: String? {
        guard let o = owner, !o.notes.isEmpty else { return nil }
        return o.notes
    }
    var petNotes: [String] {
        pets.compactMap { p -> String? in
            var bits: [String] = []
            if p.biteLevel == 2 { bits.append(L("BITES", "咬人")) }
            else if p.biteLevel == 1 { bits.append(L("handle with care", "谨慎")) }
            if !p.temperament.isEmpty { bits.append(p.temperament) }
            if p.status == .sick { bits.append(L("sick", "生病中")) }
            guard !bits.isEmpty else { return nil }
            return "\(p.type.emoji)\(p.name): " + bits.joined(separator: " · ")
        }
    }
    var toolNotes: [String] {
        pets.map { $0.specialTools }.filter { !$0.isEmpty }
    }

    var tf: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale = Locale(identifier: AppLang.current == .en ? "en_US" : "zh_CN")
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(owner?.name ?? L("Unknown client", "未知客户"))
                    .font(.headline)
                Spacer()
                // 健哥11-20令⑥：右侧改显示准备/结束时间（有闹钟才有；无闹钟=预约时间）
                VStack(alignment: .trailing, spacing: 2) {
                    if let prep = appt.prepAlarm {
                        Label(tf.string(from: prep), systemImage: "laptopcomputer.and.iphone")
                            .font(.caption2).foregroundColor(.blue)
                    }
                    if let depart = appt.departAlarm {
                        Label(tf.string(from: depart), systemImage: "car.fill")
                            .font(.caption2).foregroundColor(.red)
                    } else {
                        Text(tf.string(from: appt.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let end = appt.endAlarm {
                        Label(tf.string(from: end), systemImage: "checkmark.circle")
                            .font(.caption2).foregroundColor(.green)
                    }
                }
            }
            if !pets.isEmpty {
                Text(pets.map { "\($0.type.emoji)\($0.name)" }.joined(separator: " ")
                     + " · \(appt.groomMinutes) " + L("min", "分钟")
                     + " · " + L("buffer \(appt.driveBufferMinutes) min", "缓冲\(appt.driveBufferMinutes)分钟"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !appt.remindMinutesList.isEmpty && appt.prepAlarm == nil && appt.departAlarm == nil && appt.endAlarm == nil {
                Label(L10n.remindLabel(appt.remindMinutesList), systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            // 健哥令第七轮⑥：注意事项三线（有则显示）
            if let cn = clientNote {
                Label(L("Client note", "客户备注") + ": " + cn, systemImage: "person.crop.square.and.at.rectangle")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            ForEach(petNotes, id: \.self) { note in
                Label(note, systemImage: "pawprint")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if !toolNotes.isEmpty {
                Label(L10n.toolsNeeded(toolNotes), systemImage: "suitcase.cart")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if !appt.note.isEmpty {
                Label(appt.note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let warn = noShowWarn {
                Label(warn, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            HStack(spacing: 12) {
                Button {
                    update(.done)
                } label: {
                    Label(L("Done", "完成"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    update(.noshow)
                } label: {
                    Label(L("No-show", "没成功"), systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private func update(_ st: Appointment.Status) {
        guard TrialStore.gate() else { return }   // 11-24试用制：到期锁完成/没来
        if let i = data.appointments.firstIndex(where: { $0.id == appt.id }) {
            data.appointments[i].status = st
            if st == .noshow {
                if let oi = data.owners.firstIndex(where: { $0.id == appt.ownerId }) {
                    data.owners[oi].noShowCount += 1
                }
                for pi in data.pets.indices where appt.petIds.contains(data.pets[pi].id) {
                    data.pets[pi].noShowCount += 1
                }
            }
            if st != .scheduled {
                ReminderScheduler.cancel(appointmentId: appt.id)
            }
            Store.save(data)
        }
    }
}

// MARK: - Tab2 客户列表

struct ClientListView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false
    // 健哥11-21令①：总导出直传文本（Identifiable 包装——sheet(item:) 用）
    @State private var shareText: ShareTextItem?

    struct ShareTextItem: Identifiable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.owners.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text(L("No clients yet", "还没有客户"))
                            .font(.headline)
                        Text(L("You can add pets right when creating a client.", "新建客户时可以顺便录入宠物信息。"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(data.owners) { owner in
                            NavigationLink(destination: ClientDetailView(owner: owner, data: $data)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(owner.name).font(.headline)
                                        if owner.noShowCount > 0 {
                                            Text("\(owner.noShowCount) " + L("no-shows", "次没成功"))
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        let pets = data.pets.filter { $0.ownerId == owner.id }
                                        Text(pets.isEmpty ? L("No pets", "无宠物") : pets.map { "\($0.type.emoji)\($0.name)" }.joined(separator: " "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !owner.address.isEmpty {
                                            Image(systemName: "mappin").font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            guard TrialStore.gate() else { return }   // 11-24试用制：到期锁删除
                            data.owners.remove(atOffsets: offsets); Store.save(data)
                        }
                    }
                }
            }
            .navigationTitle(L("Clients", "客户"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 11-24健哥拍板：导出永远免费（到期只读策略的一部分——数据永远不是人质）
                        shareText = ShareTextItem(text: Exporter.makeText(data: data))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { if TrialStore.gate() { showAdd = true } } label: { Image(systemName: "plus") }   // 11-24试用制：到期锁新建
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                ClientEditor(data: $data, existing: nil)
            }
            // 健哥11-21令①：sheet(item:) 模式——文本即 item，构造时确定，永不为空
            .sheet(item: $shareText) { item in
                ShareSheet(items: [item.text])
            }
        }
    }
}

// MARK: - 客户详情（内嵌宠物+逐客户导出健哥令⑧）

struct ClientDetailView: View {
    let owner: Owner
    @Binding var data: Store.Data
    @State private var showEdit = false
    @State private var showAddPet = false
    @State private var exportText: String?
    @State private var showShare = false

    var current: Owner { data.owners.first { $0.id == owner.id } ?? owner }
    var myPets: [Pet] { data.pets.filter { $0.ownerId == current.id } }
    var myAppts: [Appointment] { data.appointments.filter { $0.ownerId == current.id } }

    var body: some View {
        List {
            Section(L("Contact & Address", "联系与地址")) {
                if !current.phone.isEmpty {
                    Button {
                        if let url = URL(string: "tel://\(current.phone.filter { !$0.isWhitespace && $0 != "-" })") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(current.phone, systemImage: "phone.fill")
                    }
                }
                if !current.email.isEmpty {
                    Link(destination: URL(string: "mailto:\(current.email)")!) {
                        Label(current.email, systemImage: "envelope")
                    }
                }
                if !current.address.isEmpty {
                    HStack {
                        Label(current.address, systemImage: "mappin.and.ellipse")
                        Spacer()
                        Button {
                            let q = current.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "maps://?daddr=\(q)&dirflg=d") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "map.fill")
                        }
                    }
                }
            }
            if !current.familyMembers.isEmpty {
                Section(L("Family (contacts)", "家人（对接人）")) {
                    Label(current.familyMembers, systemImage: "person.3")
                }
            }
            if !current.notes.isEmpty {
                Section(L("Preferences & Notes", "偏好与备注")) { Text(current.notes) }
            }
            if current.noShowCount > 0 {
                Section {
                    Label(L10n.noShowWarn(current.noShowCount), systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
            Section(L10n.countHeader("宠物", "Pets", myPets.count)) {
                if myPets.isEmpty {
                    Text(L("No pets yet — use the menu (top right)", "还没有宠物——右上角菜单添加")).font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myPets) { pet in
                        NavigationLink(destination: PetDetailView(pet: pet, data: $data)) {
                            PetRow(pet: pet)
                        }
                    }
                }
            }
            Section(L10n.countHeader("上门记录", "Visit History", myAppts.count)) {
                if myAppts.isEmpty {
                    Text(L("No visits yet", "还没有记录")).font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myAppts.sorted { $0.date > $1.date }.prefix(8)) { a in
                        HStack {
                            Image(systemName: a.status == .done ? "checkmark.circle" : a.status == .noshow ? "xmark.circle" : "clock")
                                .foregroundColor(a.status == .noshow ? .red : .secondary)
                            Text(a.date, style: .date)
                            Spacer()
                            Text(a.status.display).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(current.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    exportText = Exporter.makeText(data: data, ownerFilter: current.id)
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // 🔴iOS 26 系统bug：Menu按钮直接弹sheet会被菜单模态挡住——延迟一拍再赋值（N仓11-27实锤同款修法）
                    Button {
                        if TrialStore.gate() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showEdit = true }
                        }
                    } label: { Label(L("Edit Client", "编辑客户"), systemImage: "pencil") }
                    Button {
                        if TrialStore.gate() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAddPet = true }
                        }
                    } label: { Label(L("Add Pet", "加宠物"), systemImage: "plus.circle") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { data = Store.load() }) {
            ClientEditor(data: $data, existing: current)
        }
        .sheet(isPresented: $showAddPet, onDismiss: { data = Store.load() }) {
            PetEditor(data: $data, existing: nil, presetOwnerId: current.id)
        }
        .sheet(isPresented: $showShare, onDismiss: { exportText = nil }) {
            // 健哥令第五轮③：同上——不做 if-let 短路（首点必出内容）
            ShareSheet(items: [exportText ?? ""])
        }
    }
}

struct PetRow: View {
    let pet: Pet
    var body: some View {
        HStack {
            // 健哥令⑨：宠物图片
            if let img = pet.photoData, let ui = UIImage(data: img) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Text(pet.type.emoji).font(.title2)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pet.name).font(.headline)
                    if pet.biteLevel == 2 {
                        Text(L("BITES", "咬人")).font(.caption2).foregroundColor(.red)
                    } else if pet.biteLevel == 1 {
                        Text(L("CARE", "谨慎")).font(.caption2).foregroundColor(.orange)
                    }
                    // 状态标记（健哥令⑦）
                    if pet.status != .normal {
                        Text(pet.status.display)
                            .font(.caption2)
                            .foregroundColor(pet.status == .sick ? .orange : .secondary)
                    }
                }
                Text("\(pet.breed) · \(pet.type.display)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let exp = pet.vaccineExpiry, exp < Date(), pet.status == .normal {
                Image(systemName: "syringe")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - 宠物详情（含喜好健哥令⑦/图片⑨）

struct PetDetailView: View {
    let pet: Pet
    @Binding var data: Store.Data
    @State private var showEdit = false

    var current: Pet { data.pets.first { $0.id == pet.id } ?? pet }
    var owner: Owner? { data.owners.first { $0.id == current.ownerId } }

    var body: some View {
        List {
            // 大图（健哥令⑨）
            if let img = current.photoData, let ui = UIImage(data: img) {
                Section {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .listRowInsets(EdgeInsets())
                }
            }
            if let owner {
                Section(L("Owner", "主人")) {
                    NavigationLink(destination: ClientDetailView(owner: owner, data: $data)) {
                        VStack(alignment: .leading) {
                            Text(owner.name)
                            if !owner.address.isEmpty {
                                Text(owner.address).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            if current.status != .normal {
                Section {
                    Label(L("Status", "状态") + ": " + current.status.display, systemImage: current.status == .passed ? "heart.slash" : "stethoscope")
                        .foregroundColor(current.status == .sick ? .orange : .secondary)
                }
            }
            Section(L("Preferences (rapport)", "喜好（沟通时用）")) {
                if !current.favoriteFood.isEmpty {
                    Label(L("Loves: ", "爱吃：") + current.favoriteFood, systemImage: "fork.knife")
                }
                if !current.favoritePetting.isEmpty {
                    Label(L("Loves: ", "爱摸：") + current.favoritePetting, systemImage: "hand.tap")
                }
                if current.favoriteFood.isEmpty && current.favoritePetting.isEmpty {
                    Text(L("Favorite treats? Where does it like to be petted? Great for winning them over on visits.", "喜欢吃什么？喜欢怎么摸它？——上门时讨好它用。"))
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            Section(L("Grooming Recipe", "美容配方")) {
                if current.groomRecipe.isEmpty {
                    Text(L("Style / blade / shampoo notes — write once, reuse every visit.", "造型/刀头/洗毛精备注——写一次，下次直接用。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text(current.groomRecipe)
                }
            }
            Section(L("Special Tools to Bring", "特殊工具携带")) {
                if current.specialTools.isEmpty {
                    Text(L("Any special tools to bring?", "有无需要特别带的工具？"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Label(current.specialTools, systemImage: "suitcase.cart")
                        .foregroundColor(.orange)
                }
            }
            Section(L("Health & Temperament", "健康与脾气")) {
                if !current.temperament.isEmpty {
                    Label(current.temperament, systemImage: "heart")
                }
                HStack {
                    Text(L("Bite risk", "咬人风险"))
                    Spacer()
                    Text([L("Safe", "安全"), L("Care", "谨慎"), L("Bites", "咬人")][current.biteLevel])
                        .foregroundColor(current.biteLevel == 2 ? .red : current.biteLevel == 1 ? .orange : .green)
                }
                if let exp = current.vaccineExpiry {
                    HStack {
                        Label(L("Vaccine", "疫苗"), systemImage: "syringe")
                        Spacer()
                        Text(exp, style: .date)
                            .foregroundColor(exp < Date() ? .red : .primary)
                    }
                }
            }
        }
        .navigationTitle(current.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { if TrialStore.gate() { showEdit = true } } label: { Image(systemName: "pencil") }   // 11-24试用制：到期锁编辑
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { data = Store.load() }) {
            PetEditor(data: $data, existing: current, presetOwnerId: nil)
        }
    }
}

// MARK: - 系统分享面板（导出用）

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - 付费墙（11-24健哥拍板：30天试用→$14.99买断限时锁；到期只读+导出免费+锁新建）
// 文案原则（客户不满是落差问题卡）：先说"记录安全、导出永远免费"，再说"解锁继续记"——坏消息放事前。
struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.open.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)
                // A：双态文案——试用中=提前解锁；到期=试用结束
                Text(TrialStore.canWrite ? L("Unlock early — skip the wait", "提前解锁——不用等到期") : L("Your 30-day trial has ended", "30天试用已结束"))
                    .font(.title2.bold())
                VStack(alignment: .leading, spacing: 10) {
                    if TrialStore.canWrite {
                        Label(L("Trial: \(TrialStore.daysLeft) days left. Unlock now — it's yours forever.", "试用还剩 \(TrialStore.daysLeft) 天。现在解锁，终身拥有。"), systemImage: "hourglass")
                        Label(L("No subscription, no renewal — pay once", "无订阅无续费——一次付清"), systemImage: "checkmark.seal")
                    } else {
                        Label(L("Your records are safe — view & export anytime, free forever", "你的记录都在——随时查看、导出，永远免费"), systemImage: "checkmark.shield")
                        Label(L("Unlock once to keep booking visits and adding clients & pets", "解锁一次，继续约单、加客户和宠物"), systemImage: "calendar.badge.plus")
                        Label(L("One-time purchase, yours forever", "一次购买，终身拥有"), systemImage: "checkmark.seal")
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 24)
                Button {
                    purchasing = true
                    Task {
                        let ok = await ProStore.purchase()
                        purchasing = false
                        if ok { dismiss() } else { failed = true }
                    }
                } label: {
                    Label(purchasing ? L("Processing…", "处理中…") : L("Unlock — $29.99 once", "解锁 — $29.99 一次性"), systemImage: "crown")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(purchasing)
                .padding(.horizontal, 24)
                if failed {
                    Text(L("Purchase didn't complete. If you already bought it, tap Restore.", "购买未完成。如已买过，点恢复购买。"))
                        .font(.caption).foregroundColor(.red)
                }
                Button(L("Restore purchase", "恢复购买")) {
                    Task {
                        await ProStore.restore()
                        if ProStore.unlocked { dismiss() }
                    }
                }
                .font(.subheadline)
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle(L("Pro", "Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Not now", "暂不")) { dismiss() }
                }
            }
        }
    }
}
