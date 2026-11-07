import SwiftUI

// MARK: - 狗编辑器（新建/编辑）——配方P1/咬人风险P2/疫苗P6/体重档——中文 UI

struct DogEditor: View {
    @Binding var data: Store.Data
    let existing: Dog?           // nil=新建
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var breed = ""
    @State private var weight = 10.0
    @State private var ownerId: UUID?
    @State private var temperament = ""
    @State private var biteLevel = 0
    @State private var groomRecipe = ""
    @State private var hasVaccine = false
    @State private var vaccineExpiry = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("狗狗") {
                    TextField("名字", text: $name)
                    TextField("品种", text: $breed)
                    HStack {
                        Text("体重")
                        Slider(value: $weight, in: 1...70, step: 1)
                        Text("\(Int(weight)) 公斤").monospacedDigit().frame(width: 64)
                    }
                    // 体重档对应的默认时长提示（施工单）
                    Text("默认美容时长：\(defaultMinutes) 分钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("主人") {
                    if data.owners.isEmpty {
                        Text("请先在「主人」页添加主人。")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("主人", selection: $ownerId) {
                            ForEach(data.owners) { o in
                                Text(o.name).tag(Optional(o.id))
                            }
                        }
                    }
                }
                Section("脾气") {
                    Picker("咬人风险", selection: $biteLevel) {
                        Text("安全").tag(0)
                        Text("谨慎").tag(1)
                        Text("咬人").tag(2)
                    }
                    .pickerStyle(.segmented)
                    TextField("脾气备注（紧张、怕猫…）", text: $temperament, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("美容配方") {
                    TextField("刀头 / 洗毛精 / 造型备注", text: $groomRecipe, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section("疫苗") {
                    Toggle("记录疫苗到期", isOn: $hasVaccine)
                    if hasVaccine {
                        DatePicker("到期日", selection: $vaccineExpiry, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建狗狗" : "编辑狗狗")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty || ownerId == nil && !data.owners.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var defaultMinutes: Int {
        switch weight {
        case ..<8: return 60
        case ..<20: return 90
        case ..<35: return 120
        default: return 150
        }
    }

    private func load() {
        guard let d = existing else {
            ownerId = data.owners.first?.id
            return
        }
        name = d.name; breed = d.breed; weight = d.weightKg; ownerId = d.ownerId
        temperament = d.temperament; biteLevel = d.biteLevel; groomRecipe = d.groomRecipe
        if let v = d.vaccineExpiry { hasVaccine = true; vaccineExpiry = v }
    }

    private func save() {
        guard let oid = ownerId else { return }
        if var d = existing {
            if let i = data.dogs.firstIndex(where: { $0.id == d.id }) {
                d.name = name; d.breed = breed; d.weightKg = weight; d.ownerId = oid
                d.temperament = temperament; d.biteLevel = biteLevel; d.groomRecipe = groomRecipe
                d.vaccineExpiry = hasVaccine ? vaccineExpiry : nil
                data.dogs[i] = d
            }
        } else {
            data.dogs.append(Dog(name: name, breed: breed, weightKg: weight, ownerId: oid,
                                 temperament: temperament, biteLevel: biteLevel, groomRecipe: groomRecipe,
                                 vaccineExpiry: hasVaccine ? vaccineExpiry : nil))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 主人编辑器（联系方式+邮箱 健哥令① / 偏好禁忌 P3）——中文 UI

struct OwnerEditor: View {
    @Binding var data: Store.Data
    let existing: Owner?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("主人") {
                    TextField("姓名", text: $name)
                }
                Section("联系方式") {
                    TextField("电话", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("偏好与备注") {
                    TextField("性格、偏好、门禁密码、禁忌…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "新建主人" : "编辑主人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let o = existing else { return }
        name = o.name; phone = o.phone; email = o.email; notes = o.notes
    }

    private func save() {
        if var o = existing {
            if let i = data.owners.firstIndex(where: { $0.id == o.id }) {
                o.name = name; o.phone = phone; o.email = email; o.notes = notes
                data.owners[i] = o
            }
        } else {
            data.owners.append(Owner(name: name, phone: phone, email: email, notes: notes))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 预约编辑器（建预约时 no-show 警示 P4 + 默认时长按体重档）——中文 UI

struct AppointmentEditor: View {
    @Binding var data: Store.Data
    let preselectedDogId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var dogId: UUID?
    @State private var date = Date()
    @State private var minutes = 90
    @State private var buffer = 15
    @State private var note = ""

    var selectedDog: Dog? { data.dogs.first { $0.id == dogId } }
    var selectedOwner: Owner? {
        guard let d = selectedDog else { return nil }
        return data.owners.first { $0.id == d.ownerId }
    }
    var noShowWarn: String? {
        guard let d = selectedDog else { return nil }
        let total = d.noShowCount + (selectedOwner?.noShowCount ?? 0)
        return total > 0 ? "有 \(total) 次放鸽子记录——建议收押金" : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if data.dogs.isEmpty {
                        Text("请先在「狗狗」页添加狗狗。")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("狗狗", selection: $dogId) {
                            ForEach(data.dogs) { d in
                                Text(d.name).tag(Optional(d.id))
                            }
                        }
                        .onChange(of: dogId) { nv in
                            if let d = data.dogs.first(where: { $0.id == nv }) {
                                minutes = d.defaultMinutes
                            }
                        }
                    }
                }
                if let warn = noShowWarn {
                    Section {
                        Label(warn, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                Section("时间") {
                    DatePicker("日期时间", selection: $date)
                    Stepper("美容 \(minutes) 分钟", value: $minutes, in: 15...300, step: 15)
                    Stepper("车程缓冲 \(buffer) 分钟", value: $buffer, in: 0...60, step: 5)
                }
                Section("备注") {
                    TextField("选填备注", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("新建预约")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(dogId == nil)
                }
            }
            .onAppear {
                if dogId == nil {
                    dogId = preselectedDogId ?? data.dogs.first?.id
                    if let d = selectedDog { minutes = d.defaultMinutes }
                }
            }
        }
    }

    private func save() {
        guard let did = dogId else { return }
        data.appointments.append(Appointment(dogId: did, date: date, groomMinutes: minutes, driveBufferMinutes: buffer, note: note))
        Store.save(data)
        dismiss()
    }
}
