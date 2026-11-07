import SwiftUI

@main
struct GroomerBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - 根视图（三Tab：今日 / 狗狗 / 主人）——中文 UI（2026-11-07 健哥令）

struct RootView: View {
    @State private var data = Store.load()
    @State private var tab = 0

    func refresh() { data = Store.load() }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(data: $data)
                .tabItem { Label("今日", systemImage: "calendar") }
                .tag(0)
            DogListView(data: $data)
                .tabItem { Label("狗狗", systemImage: "dog") }
                .tag(1)
            OwnerListView(data: $data)
                .tabItem { Label("主人", systemImage: "person.2") }
                .tag(2)
        }
        .onAppear(perform: refresh)
    }
}

// MARK: - Tab1 今日（施工单：预约按日分组 + 该约的狗提示条 P7 + no-show 警示 P4）

struct TodayView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false

    /// 该约的狗：上次完成≥35天且无未完成的预约（P7：六周循环，提前一周提示）
    var dueSoon: [(Dog, Int)] {
        let today = Calendar.current.startOfDay(for: Date())
        var result: [(Dog, Int)] = []
        for dog in data.dogs {
            let doneDates = data.appointments
                .filter { $0.dogId == dog.id && $0.status == .done }
                .compactMap { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0.date), to: today).day }
            let hasOpen = data.appointments.contains { $0.dogId == dog.id && $0.status == .scheduled }
            if let last = doneDates.min(), last >= Appointment.reorderDays - 7, !hasOpen {
                result.append((dog, last))
            }
        }
        return result.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.appointments.isEmpty && data.dogs.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "scissors")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text("你的移动美容台账")
                            .font(.headline)
                        Text("先加主人，再加狗，然后约第一单。所有数据只留在这台手机上。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        if !dueSoon.isEmpty {
                            Section("该约了") {
                                ForEach(dueSoon, id: \.0.id) { dog, days in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(dog.name).font(.headline)
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
                        ForEach(groupedByDay, id: \.0) { day, apps in
                            Section(day) {
                                ForEach(apps) { appt in
                                    AppointmentRow(appt: appt, data: $data)
                                }
                            }
                        }
                        if data.appointments.isEmpty {
                            Text("还没有预约——从狗狗档案页添加。")
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
                AppointmentEditor(data: $data, preselectedDogId: nil)
            }
        }
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

// MARK: - 预约行（完成/没来 动作 + 快捷短信 P5）

struct AppointmentRow: View {
    let appt: Appointment
    @Binding var data: Store.Data
    @State private var copiedMsg = false

    var dog: Dog? { data.dogs.first { $0.id == appt.dogId } }
    var owner: Owner? {
        guard let dog else { return nil }
        return data.owners.first { $0.id == dog.ownerId }
    }

    /// no-show 警示（P4）：该狗或主人有过放鸽子
    var noShowWarn: String? {
        guard let dog else { return nil }
        let total = dog.noShowCount + (owner?.noShowCount ?? 0)
        return total > 0 ? "有 \(total) 次放鸽子记录——建议收押金" : nil
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
                Text(dog?.name ?? "未知")
                    .font(.headline)
                // 咬人风险标（P2）
                if let dog {
                    Circle()
                        .fill(biteColor(dog.biteLevel))
                        .frame(width: 10, height: 10)
                        .help(dog.biteLevel == 2 ? "咬人风险" : dog.biteLevel == 1 ? "需谨慎" : "")
                }
                Spacer()
                Text(tf.string(from: appt.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("美容 \(appt.groomMinutes) 分钟 · 车程缓冲 \(appt.driveBufferMinutes) 分钟")
                .font(.caption)
                .foregroundColor(.secondary)

            if let warn = noShowWarn {
                Label(warn, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 12) {
                Button {
                    markDone()
                } label: {
                    Label("完成", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    markNoShow()
                } label: {
                    Label("没来", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                // 快捷短信（P5）
                if let dog, let owner {
                    Button {
                        let msg = MessageTemplate.onMyWay(owner: owner, dog: dog, minutes: appt.driveBufferMinutes)
                        UIPasteboard.general.string = msg
                        copiedMsg = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedMsg = false }
                    } label: {
                        Label(copiedMsg ? "已复制！" : "在路上短信", systemImage: "message.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func biteColor(_ level: Int) -> Color {
        switch level { case 2: return .red; case 1: return .yellow; default: return .green }
    }

    private func markDone() {
        if let idx = data.appointments.firstIndex(where: { $0.id == appt.id }) {
            data.appointments[idx].status = .done
            Store.save(data)
        }
    }

    private func markNoShow() {
        if let idx = data.appointments.firstIndex(where: { $0.id == appt.id }) {
            data.appointments[idx].status = .noshow
            // P4：狗+主人双计数
            if let di = data.dogs.firstIndex(where: { $0.id == appt.dogId }) {
                data.dogs[di].noShowCount += 1
            }
            if let dog = dog, let oi = data.owners.firstIndex(where: { $0.id == dog.ownerId }) {
                data.owners[oi].noShowCount += 1
            }
            Store.save(data)
        }
    }
}

// MARK: - Tab2 狗狗列表（红风险置顶 P2）

struct DogListView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false

    var sorted: [Dog] {
        data.dogs.sorted { a, b in
            if a.biteLevel != b.biteLevel { return a.biteLevel > b.biteLevel }
            return a.name < b.name
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if data.dogs.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "dog")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text("还没有狗狗")
                            .font(.headline)
                        Text("添加狗狗：美容配方、脾气、疫苗日期。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sorted) { dog in
                            NavigationLink(destination: DogDetailView(dog: dog, data: $data)) {
                                DogRow(dog: dog, ownerName: data.owners.first { $0.id == dog.ownerId }?.name ?? "—")
                            }
                        }
                        .onDelete { data.dogs.remove(atOffsets: $0); Store.save(data) }
                    }
                }
            }
            .navigationTitle("狗狗")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                DogEditor(data: $data, existing: nil)
            }
        }
    }
}

struct DogRow: View {
    let dog: Dog
    let ownerName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dog.name).font(.headline)
                    if dog.biteLevel == 2 {
                        Label("咬人风险", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else if dog.biteLevel == 1 {
                        Text("谨慎")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Text("\(dog.breed) · \(ownerName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let exp = dog.vaccineExpiry, exp < Date() {
                Image(systemName: "syringe")
                    .foregroundColor(.red)
                    .help("疫苗已过期")
            }
        }
    }
}

// MARK: - 狗详情（配方 P1 + 从上次复制 + 访问历史）

struct DogDetailView: View {
    let dog: Dog
    @Binding var data: Store.Data
    @State private var showEdit = false
    @State private var showBook = false

    var current: Dog { data.dogs.first { $0.id == dog.id } ?? dog }
    var owner: Owner? { data.owners.first { $0.id == current.ownerId } }
    var history: [Appointment] {
        data.appointments.filter { $0.dogId == current.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            // 配方卡（P1）
            Section("美容配方") {
                if current.groomRecipe.isEmpty {
                    Text("刀头 / 洗毛精 / 造型备注——写一次，永久复用。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text(current.groomRecipe)
                }
            }
            // 脾气+疫苗+no-show（P2/P6/P4）
            Section("健康与脾气") {
                if !current.temperament.isEmpty {
                    Label(current.temperament, systemImage: "heart")
                }
                HStack {
                    Text("咬人风险")
                    Spacer()
                    Text(["安全", "谨慎", "咬人风险"][current.biteLevel])
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
                if current.noShowCount > 0 {
                    Label("放鸽子 \(current.noShowCount) 次", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
            // 主人联系（P3/健哥令①）
            if let owner {
                Section("主人") {
                    NavigationLink(destination: OwnerDetailView(owner: owner, data: $data)) {
                        VStack(alignment: .leading) {
                            Text(owner.name)
                            if !owner.phone.isEmpty { Text(owner.phone).font(.caption).foregroundColor(.secondary) }
                            if !owner.email.isEmpty { Text(owner.email).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                }
            }
            // 访问历史
            Section("历史") {
                if history.isEmpty {
                    Text("还没有上门记录").font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(history.prefix(10)) { appt in
                        HStack {
                            Image(systemName: appt.status == .done ? "checkmark.circle" : appt.status == .noshow ? "xmark.circle" : "clock")
                                .foregroundColor(appt.status == .noshow ? .red : .secondary)
                            Text(appt.date, style: .date)
                            Spacer()
                            Text(statusText(appt.status)).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(current.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("编辑", systemImage: "pencil") }
                    Button { showBook = true } label: { Label("约一单", systemImage: "calendar.badge.plus") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { data = Store.load() }) {
            DogEditor(data: $data, existing: current)
        }
        .sheet(isPresented: $showBook, onDismiss: { data = Store.load() }) {
            AppointmentEditor(data: $data, preselectedDogId: current.id)
        }
    }

    private func statusText(_ s: Appointment.Status) -> String {
        switch s { case .done: return "完成"; case .noshow: return "没来"; default: return "已约" }
    }
}

// MARK: - Tab3 主人列表

struct OwnerListView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if data.owners.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                        Text("还没有主人")
                            .font(.headline)
                        Text("主人档案：联系方式、偏好、放鸽子记录。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(data.owners) { owner in
                            NavigationLink(destination: OwnerDetailView(owner: owner, data: $data)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(owner.name).font(.headline)
                                        if owner.noShowCount > 0 {
                                            Text("放鸽子 \(owner.noShowCount) 次")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    let dogs = data.dogs.filter { $0.ownerId == owner.id }
                                    Text(dogs.isEmpty ? "暂无狗狗" : dogs.map { $0.name }.joined(separator: "、"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { data.owners.remove(atOffsets: $0); Store.save(data) }
                    }
                }
            }
            .navigationTitle("主人")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                OwnerEditor(data: $data, existing: nil)
            }
        }
    }
}

// MARK: - 主人详情（联系方式+邮箱 健哥令① + 名下狗）

struct OwnerDetailView: View {
    let owner: Owner
    @Binding var data: Store.Data
    @State private var showEdit = false

    var current: Owner { data.owners.first { $0.id == owner.id } ?? owner }
    var myDogs: [Dog] { data.dogs.filter { $0.ownerId == current.id } }

    var body: some View {
        List {
            Section("联系方式") {
                if !current.phone.isEmpty {
                    Link(destination: URL(string: "tel://\(current.phone.filter { !$0.isWhitespace })")!) {
                        Label(current.phone, systemImage: "phone")
                    }
                }
                if !current.email.isEmpty {
                    Link(destination: URL(string: "mailto:\(current.email)")!) {
                        Label(current.email, systemImage: "envelope")
                    }
                }
                if current.phone.isEmpty && current.email.isEmpty {
                    Text("还没有联系方式——点右上角编辑补充电话和邮箱。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            if !current.notes.isEmpty {
                Section("偏好与备注") {
                    Text(current.notes)
                }
            }
            if current.noShowCount > 0 {
                Section {
                    Label("放鸽子 \(current.noShowCount) 次", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
            Section("狗狗") {
                if myDogs.isEmpty {
                    Text("暂无狗狗").font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myDogs) { dog in
                        NavigationLink(destination: DogDetailView(dog: dog, data: $data)) {
                            DogRow(dog: dog, ownerName: current.name)
                        }
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
            OwnerEditor(data: $data, existing: current)
        }
    }
}
