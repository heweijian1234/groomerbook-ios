import SwiftUI
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

// MARK: - 本地通知（健哥令⑩：预约闹钟）

enum ReminderScheduler {
    /// 预约闹钟（健哥令⑩-v2：最多3个提醒，[60,120,180]式分钟数组）
    static func schedule(appointment: Appointment, ownerName: String, petNames: String) {
        let center = UNUserNotificationCenter.current()
        // 先取消旧的
        cancel(appointmentId: appointment.id)
        guard appointment.status == .scheduled else { return }

        let hoursText = { (mins: Int) -> String in
            mins >= 60 ? "提前 \(mins / 60) 小时" : "提前 \(mins) 分钟"
        }
        var idx = 0
        for mins in appointment.remindMinutesList {
            let triggerDate = appointment.date.addingTimeInterval(-Double(mins) * 60)
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "上门提醒（\(hoursText(mins))）"
            content.body = "\(hoursText(mins))出发去 \(ownerName) 家（\(petNames)）。\(mins >= 120 ? "记得带齐工具。" : "")"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(appointment.id.uuidString)-\(idx)", content: content, trigger: trigger)
            center.add(request)
            idx += 1
        }
    }

    static func cancel(appointmentId: UUID) {
        // 数组闹钟：清掉全部可能存在的带序号 identifier
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

    var body: some View {
        TabView(selection: $tab) {
            TodayView(data: $data)
                .tabItem { Label("今日", systemImage: "calendar") }
                .tag(0)
            ClientListView(data: $data)
                .tabItem { Label("客户", systemImage: "person.2") }
                .tag(1)
            PetListView(data: $data)
                .tabItem { Label("宠物", systemImage: "pawprint") }
                .tag(2)
            FeedbackView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .onAppear { data = Store.load() }
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
                        Text("你的移动美容台账")
                            .font(.headline)
                        Text("先加客户（含宠物），然后约第一单。所有数据只留在这台手机上。")
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
                            Section("该约了") {
                                ForEach(dueSoon, id: \.0.id) { pet, days in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("\(pet.type.emoji) \(pet.name)").font(.headline)
                                            Text("距上次美容 \(days) 天")
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
                                        editingAppt = appt
                                    } label: {
                                        AppointmentRow(appt: appt, data: $data)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .onDelete { offsets in
                                    for i in offsets {
                                        ReminderScheduler.cancel(appointmentId: appts[i].id)
                                        data.appointments.removeAll { $0.id == appts[i].id }
                                    }
                                    Store.save(data)
                                }
                            }
                        }
                        if data.appointments.isEmpty && !data.owners.isEmpty {
                            Text("还没有预约——点右上角添加。")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
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
        df.dateFormat = "M月d日 EEEE"
        df.locale = Locale(identifier: "zh_CN")
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
                Text("📍 今天上门").font(.headline)
                Spacer()
                Text(appt.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            if !petNames.isEmpty {
                Text("\(petNames) · \(appt.groomMinutes)分钟").font(.caption).foregroundColor(.secondary)
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
                        Label("导航", systemImage: "map.fill")
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
                        Label("拨打", systemImage: "phone.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !toolsNeeded.isEmpty {
                Label("带：\(toolsNeeded.joined(separator: "；"))", systemImage: "suitcase.cart")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            // 健哥令第五轮①：在路上短信已删——换编辑入口
            HStack {
                Spacer()
                Button {
                    editingAppt = appt
                } label: {
                    Label("编辑此单", systemImage: "pencil")
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
        return (owner.noShowCount + petCount) > 0 ? "有 \(owner.noShowCount + petCount) 次没成功记录——建议收押金" : nil
    }

    var tf: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(owner?.name ?? "未知客户")
                    .font(.headline)
                Spacer()
                Text(tf.string(from: appt.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !pets.isEmpty {
                Text(pets.map { "\($0.type.emoji)\($0.name)" }.joined(separator: " ") + " · \(appt.groomMinutes)分钟 · 缓冲\(appt.driveBufferMinutes)分钟")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !appt.remindMinutesList.isEmpty {
                let labels = appt.remindMinutesList.sorted().map { mins in
                    mins >= 60 ? "提前\(mins / 60)小时" : "提前\(mins)分钟"
                }.joined(separator: "、")
                Label(labels + "提醒", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
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
                    Label("完成", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    update(.noshow)
                } label: {
                    Label("没成功", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private func update(_ st: Appointment.Status) {
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
    @State private var exportText: String?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            Group {
                if data.owners.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text("还没有客户")
                            .font(.headline)
                        Text("新建客户时可以顺便录入宠物信息。")
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
                                            Text("\(owner.noShowCount) 次没成功")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    HStack(spacing: 8) {
                                        let pets = data.pets.filter { $0.ownerId == owner.id }
                                        Text(pets.isEmpty ? "无宠物" : pets.map { "\($0.type.emoji)\($0.name)" }.joined(separator: " "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !owner.address.isEmpty {
                                            Image(systemName: "mappin").font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { data.owners.remove(atOffsets: $0); Store.save(data) }
                    }
                }
            }
            .navigationTitle("客户")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        exportText = Exporter.makeText(data: data)
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                ClientEditor(data: $data, existing: nil)
            }
            .sheet(isPresented: $showShare, onDismiss: { exportText = nil }) {
                // 健哥令第五轮③：卡死根因=首帧时 exportText 还没就绪渲染空 sheet。
                // 改：始终构造（text 为空时给占位），不再 if-let 短路
                ShareSheet(items: [exportText ?? ""])
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
            Section("联系与地址") {
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
                Section("家人（对接人）") {
                    Label(current.familyMembers, systemImage: "person.3")
                }
            }
            if !current.notes.isEmpty {
                Section("偏好与备注") { Text(current.notes) }
            }
            if current.noShowCount > 0 {
                Section {
                    Label("\(current.noShowCount) 次没成功记录", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
            Section("宠物（\(myPets.count)）") {
                if myPets.isEmpty {
                    Text("还没有宠物——右上角菜单添加").font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myPets) { pet in
                        NavigationLink(destination: PetDetailView(pet: pet, data: $data)) {
                            PetRow(pet: pet)
                        }
                    }
                }
            }
            Section("上门记录（\(myAppts.count)）") {
                if myAppts.isEmpty {
                    Text("还没有记录").font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myAppts.sorted { $0.date > $1.date }.prefix(8)) { a in
                        HStack {
                            Image(systemName: a.status == .done ? "checkmark.circle" : a.status == .noshow ? "xmark.circle" : "clock")
                                .foregroundColor(a.status == .noshow ? .red : .secondary)
                            Text(a.date, style: .date)
                            Spacer()
                            Text(a.status.rawValue).font(.caption).foregroundColor(.secondary)
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
                    Button { showEdit = true } label: { Label("编辑客户", systemImage: "pencil") }
                    Button { showAddPet = true } label: { Label("加宠物", systemImage: "plus.circle") }
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

// MARK: - Tab3 宠物列表

struct PetListView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false

    var sorted: [Pet] {
        data.pets.sorted { a, b in
            if a.biteLevel != b.biteLevel { return a.biteLevel > b.biteLevel }
            return a.name < b.name
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.pets.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "pawprint")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text("还没有宠物")
                            .font(.headline)
                        Text("宠物在新建客户时可顺便录入，也可在这里添加。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sorted) { pet in
                            NavigationLink(destination: PetDetailView(pet: pet, data: $data)) {
                                PetRow(pet: pet)
                            }
                        }
                        .onDelete { data.pets.remove(atOffsets: $0); Store.save(data) }
                    }
                }
            }
            .navigationTitle("宠物")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                PetEditor(data: $data, existing: nil, presetOwnerId: nil)
            }
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
                        Text("咬人").font(.caption2).foregroundColor(.red)
                    } else if pet.biteLevel == 1 {
                        Text("谨慎").font(.caption2).foregroundColor(.orange)
                    }
                    // 状态标记（健哥令⑦）
                    if pet.status != .normal {
                        Text(pet.status.rawValue)
                            .font(.caption2)
                            .foregroundColor(pet.status == .sick ? .orange : .secondary)
                    }
                }
                Text("\(pet.breed) · \(pet.type.rawValue)")
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
                Section("主人") {
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
                    Label("状态：\(current.status.rawValue)", systemImage: current.status == .passed ? "heart.slash" : "stethoscope")
                        .foregroundColor(current.status == .sick ? .orange : .secondary)
                }
            }
            Section("喜好（沟通时用）") {
                if !current.favoriteFood.isEmpty {
                    Label("爱吃：\(current.favoriteFood)", systemImage: "fork.knife")
                }
                if !current.favoritePetting.isEmpty {
                    Label("爱摸：\(current.favoritePetting)", systemImage: "hand.tap")
                }
                if current.favoriteFood.isEmpty && current.favoritePetting.isEmpty {
                    Text("喜欢吃什么？喜欢怎么摸它？——上门时讨好它用。")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            Section("美容配方") {
                if current.groomRecipe.isEmpty {
                    Text("造型/刀头/洗毛精备注——写一次，下次直接用。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text(current.groomRecipe)
                }
            }
            Section("特殊工具携带") {
                if current.specialTools.isEmpty {
                    Text("有无需要特别带的工具？")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Label(current.specialTools, systemImage: "suitcase.cart")
                        .foregroundColor(.orange)
                }
            }
            Section("健康与脾气") {
                if !current.temperament.isEmpty {
                    Label(current.temperament, systemImage: "heart")
                }
                HStack {
                    Text("咬人风险")
                    Spacer()
                    Text(["安全", "谨慎", "咬人"][current.biteLevel])
                        .foregroundColor(current.biteLevel == 2 ? .red : current.biteLevel == 1 ? .orange : .green)
                }
                if let exp = current.vaccineExpiry {
                    HStack {
                        Label("疫苗", systemImage: "syringe")
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
                Button { showEdit = true } label: { Image(systemName: "pencil") }
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
