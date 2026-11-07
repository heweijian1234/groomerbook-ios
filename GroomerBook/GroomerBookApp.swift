import SwiftUI

@main
struct GroomerBookApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - 根视图 v2（健哥令②以人为主：今日/客户（主人在上） /宠物（挂客户下） /我的）

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

// MARK: - Tab1 今日（首页：地址+电话直显/一键拨号/导航 N5 + 该约了 + 预约列表）

struct TodayView: View {
    @Binding var data: Store.Data
    @State private var showAdd = false

    /// 该约了：上次完成≥35天且无未完成的预约
    var dueSoon: [(Pet, Int)] {
        let today = Calendar.current.startOfDay(for: Date())
        var result: [(Pet, Int)] = []
        for pet in data.pets {
            let doneDays = data.appointments
                .filter { $0.petId == pet.id && $0.status == .done }
                .compactMap { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0.date), to: today).day }
            let hasOpen = data.appointments.contains { $0.petId == pet.id && $0.status == .scheduled }
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
                        Text("先加客户，再加宠物，然后约第一单。所有数据只留在这台手机上。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    List {
                        // 今日上门卡（健哥令⑥：地址+电话直显在首页）
                        ForEach(todayAppointments) { appt in
                            if let pet = data.pets.first(where: { $0.id == appt.petId }),
                               let owner = data.owners.first(where: { $0.id == pet.ownerId }) {
                                TodayVisitCard(appt: appt, pet: pet, owner: owner)
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
                                    AppointmentRow(appt: appt, data: $data)
                                }
                            }
                        }
                        if data.appointments.isEmpty && !data.pets.isEmpty {
                            Text("还没有预约——从宠物档案页添加。")
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
                AppointmentEditor(data: $data, preselectedPetId: nil)
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

// MARK: - 今日上门卡（地址直显/一键拨号/一键导航/短信——健哥令⑥+N4）

struct TodayVisitCard: View {
    let appt: Appointment
    let pet: Pet
    let owner: Owner
    @State private var copiedMsg = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📍 今天上门").font(.headline)
                Spacer()
                Text(appt.date, style: .time).font(.caption).foregroundColor(.secondary)
            }
            // 地址直显 + 点击导航（健哥令⑥+N4：上门服务=去客户家，导航直达）
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
            } else {
                Text("未填地址——到客户档案补上")
                    .font(.caption).foregroundColor(.orange)
            }
            // 电话直拨（健哥令⑥）
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
            HStack {
                Text("\(pet.type.emoji) \(pet.name) · \(appt.groomMinutes)分钟")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = MessageTemplate.onMyWay(owner: owner, pet: pet, minutes: appt.driveBufferMinutes)
                    copiedMsg = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedMsg = false }
                } label: {
                    Label(copiedMsg ? "已复制！" : "在路上短信", systemImage: "message.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预约行（完成/没成功 动作——健哥令④措辞）

struct AppointmentRow: View {
    let appt: Appointment
    @Binding var data: Store.Data

    var pet: Pet? { data.pets.first { $0.id == appt.petId } }
    var owner: Owner? {
        guard let pet else { return nil }
        return data.owners.first { $0.id == pet.ownerId }
    }

    var noShowWarn: String? {
        guard let pet else { return nil }
        let total = pet.noShowCount + (owner?.noShowCount ?? 0)
        return total > 0 ? "有 \(total) 次没成功记录——建议收押金" : nil
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
                Text(pet.map { "\($0.type.emoji) \($0.name)" } ?? "未知")
                    .font(.headline)
                if let pet {
                    Circle()
                        .fill(pet.biteLevel == 2 ? Color.red : pet.biteLevel == 1 ? Color.yellow : Color.green)
                        .frame(width: 10, height: 10)
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
                if let pi = data.pets.firstIndex(where: { $0.id == appt.petId }) {
                    data.pets[pi].noShowCount += 1
                }
                if let pet = pet, let oi = data.owners.firstIndex(where: { $0.id == pet.ownerId }) {
                    data.owners[oi].noShowCount += 1
                }
            }
            Store.save(data)
        }
    }
}

// MARK: - Tab2 客户列表（健哥令②：主人在上，宠物挂客户详情内；客户带地址/家人/通讯录选人入口）

struct ClientListView: View {
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
                        Text("还没有客户")
                            .font(.headline)
                        Text("美容师是与人打交道的——客户是第一实体，宠物挂在客户下。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd, onDismiss: { data = Store.load() }) {
                ClientEditor(data: $data, existing: nil)
            }
        }
    }
}

// MARK: - 客户详情（宠物列表挂下方 + 家人 + 地址导航 + 通讯录引导）

struct ClientDetailView: View {
    let owner: Owner
    @Binding var data: Store.Data
    @State private var showEdit = false
    @State private var showAddPet = false

    var current: Owner { data.owners.first { $0.id == owner.id } ?? owner }
    var myPets: [Pet] { data.pets.filter { $0.ownerId == current.id } }

    var body: some View {
        List {
            // 联系+地址（健哥令⑥）
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
                } else {
                    Label("未填上门地址", systemImage: "mappin.slash")
                        .foregroundColor(.orange)
                        .font(.footnote)
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
            // 宠物挂客户下（健哥令②：一主人多宠物）
            Section("宠物（\(myPets.count)）") {
                if myPets.isEmpty {
                    Text("还没有宠物——点右上角编辑或下方按钮添加").font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(myPets) { pet in
                        NavigationLink(destination: PetDetailView(pet: pet, data: $data)) {
                            PetRow(pet: pet)
                        }
                    }
                }
            }
        }
        .navigationTitle(current.name)
        .toolbar {
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
    }
}

// MARK: - Tab3 宠物列表（健哥令②：排在客户页下方/结构上挂客户；独立 Tab 便于快速查）

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
                        Text("宠物挂在客户下——也可在这里独立添加。")
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
            Text(pet.type.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pet.name).font(.headline)
                    if pet.biteLevel == 2 {
                        Text("咬人").font(.caption2).foregroundColor(.red)
                    } else if pet.biteLevel == 1 {
                        Text("谨慎").font(.caption2).foregroundColor(.orange)
                    }
                }
                Text("\(pet.breed) · \(pet.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let exp = pet.vaccineExpiry, exp < Date() {
                Image(systemName: "syringe")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - 宠物详情（配方/特殊工具健哥令⑧/疫苗/历史）

struct PetDetailView: View {
    let pet: Pet
    @Binding var data: Store.Data
    @State private var showEdit = false
    @State private var showBook = false

    var current: Pet { data.pets.first { $0.id == pet.id } ?? pet }
    var owner: Owner? { data.owners.first { $0.id == current.ownerId } }
    var history: [Appointment] {
        data.appointments.filter { $0.petId == current.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
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
            Section("美容配方") {
                if current.groomRecipe.isEmpty {
                    Text("造型/刀头/洗毛精备注——写一次，下次直接用。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text(current.groomRecipe)
                }
            }
            // 特殊工具（健哥令⑧：避免忘带）
            Section("特殊工具携带") {
                if current.specialTools.isEmpty {
                    Text("有无需要特别带的工具？（如大型犬专用吹水机/猫用嘴套）")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Label(current.specialTools, systemImage: "suitcase.cart")
                        .foregroundColor(current.specialTools.isEmpty ? .primary : .orange)
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
                if current.noShowCount > 0 {
                    Label("\(current.noShowCount) 次没成功", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            }
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
                            Text(appt.status.rawValue).font(.caption).foregroundColor(.secondary)
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
            PetEditor(data: $data, existing: current, presetOwnerId: nil)
        }
        .sheet(isPresented: $showBook, onDismiss: { data = Store.load() }) {
            AppointmentEditor(data: $data, preselectedPetId: current.id)
        }
    }
}
