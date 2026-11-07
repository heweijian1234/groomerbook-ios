import SwiftUI
import ContactsUI

// MARK: - 客户编辑器 v2（健哥令⑥：地址/家人/通讯录选人；②：客户为主实体）

struct ClientEditor: View {
    @Binding var data: Store.Data
    let existing: Owner?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var familyMembers = ""
    @State private var notes = ""
    @State private var showContactPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("姓名", text: $name)
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("从通讯录选择", systemImage: "person.crop.rectangle.badge.plus")
                    }
                }
                Section("联系") {
                    TextField("电话（点击可自动拨号）", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("上门地址") {
                    TextField("小区/门牌/楼层（首页可导航）", text: $address, axis: .vertical)
                        .lineLimit(2...3)
                }
                Section("家人") {
                    TextField("家里谁对接？（如：老婆王芳收狗/儿子负责开门）", text: $familyMembers, axis: .vertical)
                        .lineLimit(2...3)
                }
                Section("偏好与备注") {
                    TextField("性格、偏好、门禁密码、禁忌…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "新建客户" : "编辑客户")
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
            .sheet(isPresented: $showContactPicker) {
                ContactPicker { contact in
                    if let contact {
                        if name.isEmpty { name = contact.name }
                        if phone.isEmpty { phone = contact.phone }
                        if email.isEmpty { email = contact.email }
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let o = existing else { return }
        name = o.name; phone = o.phone; email = o.email
        address = o.address; familyMembers = o.familyMembers; notes = o.notes
    }

    private func save() {
        if var o = existing {
            if let i = data.owners.firstIndex(where: { $0.id == o.id }) {
                o.name = name; o.phone = phone; o.email = email
                o.address = address; o.familyMembers = familyMembers; o.notes = notes
                data.owners[i] = o
            }
        } else {
            data.owners.append(Owner(name: name, phone: phone, email: email, address: address,
                                     familyMembers: familyMembers, notes: notes))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 通讯录选择器（健哥令⑥：电话能从手机通讯录选）

struct ContactPickerResult {
    var name: String
    var phone: String
    var email: String
}

struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (ContactPickerResult?) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (ContactPickerResult?) -> Void
        init(onPick: @escaping (ContactPickerResult?) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let email = contact.emailAddresses.first?.value as String? ?? ""
            onPick(ContactPickerResult(name: name, phone: phone, email: email))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPick(nil)
        }
    }
}

// MARK: - 宠物编辑器 v2（健哥令⑦：宠物类型可选/自填；⑧特殊工具；②挂客户）

struct PetEditor: View {
    @Binding var data: Store.Data
    let existing: Pet?
    let presetOwnerId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: PetType = .dog
    @State private var customType = ""
    @State private var breed = ""
    @State private var weight = 10.0
    @State private var ownerId: UUID?
    @State private var temperament = ""
    @State private var biteLevel = 0
    @State private var groomRecipe = ""
    @State private var specialTools = ""
    @State private var hasVaccine = false
    @State private var vaccineExpiry = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("宠物") {
                    TextField("名字", text: $name)
                    // 宠物类型（健哥令⑦：不止狗——可选或自填）
                    Picker("类型", selection: $type) {
                        ForEach(PetType.allCases, id: \.self) { t in
                            Text("\(t.emoji) \(t.rawValue)").tag(t)
                        }
                    }
                    if type == .other {
                        TextField("填类型（如：刺猬/龙猫/猪）", text: $customType)
                    }
                    TextField("品种", text: $breed)
                    HStack {
                        Text("体重")
                        Slider(value: $weight, in: 1...70, step: 1)
                        Text("\(Int(weight)) 公斤").monospacedDigit().frame(width: 64)
                    }
                    Text("默认美容时长：\(defaultMinutes) 分钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("主人") {
                    if data.owners.isEmpty {
                        Text("请先在「客户」页添加客户。")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("客户", selection: $ownerId) {
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
                    TextField("造型 / 刀头 / 洗毛精备注", text: $groomRecipe, axis: .vertical)
                        .lineLimit(4...8)
                }
                // 特殊工具（健哥令⑧：避免忘带）
                Section("特殊工具携带") {
                    TextField("上门要特别带的工具？（大型犬吹水机/猫嘴套/电剪备用电池…）", text: $specialTools, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("疫苗") {
                    Toggle("记录疫苗到期", isOn: $hasVaccine)
                    if hasVaccine {
                        DatePicker("到期日", selection: $vaccineExpiry, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(existing == nil ? "新建宠物" : "编辑宠物")
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
        let base: Int
        switch weight {
        case ..<8: base = 60
        case ..<20: base = 90
        case ..<35: base = 120
        default: base = 150
        }
        return type == .cat ? max(45, base - 15) : base
    }

    private func load() {
        guard let p = existing else {
            ownerId = presetOwnerId ?? data.owners.first?.id
            return
        }
        name = p.name; type = p.type; breed = p.breed; weight = p.weightKg; ownerId = p.ownerId
        temperament = p.temperament; biteLevel = p.biteLevel; groomRecipe = p.groomRecipe
        specialTools = p.specialTools
        if let v = p.vaccineExpiry { hasVaccine = true; vaccineExpiry = v }
    }

    private func save() {
        guard let oid = ownerId else { return }
        let finalType: PetType = type
        if var p = existing {
            if let i = data.pets.firstIndex(where: { $0.id == p.id }) {
                p.name = name; p.type = finalType; p.breed = breed; p.weightKg = weight; p.ownerId = oid
                p.temperament = temperament; p.biteLevel = biteLevel; p.groomRecipe = groomRecipe
                p.specialTools = specialTools
                p.vaccineExpiry = hasVaccine ? vaccineExpiry : nil
                data.pets[i] = p
            }
        } else {
            data.pets.append(Pet(name: name, type: finalType, breed: breed, weightKg: weight, ownerId: oid,
                                 temperament: temperament, biteLevel: biteLevel, groomRecipe: groomRecipe,
                                 specialTools: specialTools, vaccineExpiry: hasVaccine ? vaccineExpiry : nil))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 预约编辑器（没成功警示 + 默认时长按体重/类型）

struct AppointmentEditor: View {
    @Binding var data: Store.Data
    let preselectedPetId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var petId: UUID?
    @State private var date = Date()
    @State private var minutes = 90
    @State private var buffer = 15
    @State private var note = ""

    var selectedPet: Pet? { data.pets.first { $0.id == petId } }
    var selectedOwner: Owner? {
        guard let p = selectedPet else { return nil }
        return data.owners.first { $0.id == p.ownerId }
    }
    var noShowWarn: String? {
        guard let p = selectedPet else { return nil }
        let total = p.noShowCount + (selectedOwner?.noShowCount ?? 0)
        return total > 0 ? "⚠️ 有 \(total) 次没成功记录——建议收押金" : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if data.pets.isEmpty {
                        Text("请先添加宠物。")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("宠物", selection: $petId) {
                            ForEach(data.pets) { p in
                                Text("\(p.type.emoji) \(p.name)").tag(Optional(p.id))
                            }
                        }
                        .onChange(of: petId) { nv in
                            if let p = data.pets.first(where: { $0.id == nv }) {
                                minutes = p.defaultMinutes
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
                    DatePicker("日期与时间", selection: $date)
                    Stepper("\(minutes) 分钟美容", value: $minutes, in: 15...300, step: 15)
                    Stepper("\(buffer) 分钟车程缓冲", value: $buffer, in: 0...60, step: 5)
                }
                Section("备注") {
                    TextField("备注（可选）", text: $note, axis: .vertical)
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
                        .disabled(petId == nil)
                }
            }
            .onAppear {
                if petId == nil {
                    petId = preselectedPetId ?? data.pets.first?.id
                    if let p = selectedPet { minutes = p.defaultMinutes }
                }
            }
        }
    }

    private func save() {
        guard let pid = petId else { return }
        data.appointments.append(Appointment(petId: pid, date: date, groomMinutes: minutes, driveBufferMinutes: buffer, note: note))
        Store.save(data)
        dismiss()
    }
}

// MARK: - 我的/反馈页（健哥令⑤：用户反馈收集）

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section("反馈意见") {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if feedbackText.isEmpty {
                                    Text("用着哪里不顺？缺什么功能？想到什么说什么——直接写。")
                                        .foregroundColor(.secondary)
                                        .font(.footnote)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                }
                            }
                        )
                }
                Section {
                    Button {
                        // 邮件反馈：mailto 带正文（用户自己的邮件 App 发出——无服务器、无埋点，纯本地 App 的反馈通道）
                        let subject = "宠物美容台账-用户反馈"
                        let body = feedbackText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "mailto:zeronelabs.dev@gmail.com?subject=\(subject)&body=\(body)") {
                            UIApplication.shared.open(url)
                            sent = true
                        }
                    } label: {
                        Label(sent ? "已打开邮件——发送即完成反馈" : "发送反馈（走你的邮件）", systemImage: "paperplane.fill")
                    }
                    .disabled(feedbackText.isEmpty)
                } footer: {
                    Text("反馈通过邮件直达开发者，不留任何数据在 App 里。")
                }
            }
            .navigationTitle("我的")
        }
    }
}
