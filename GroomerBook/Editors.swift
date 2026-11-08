import SwiftUI
import ContactsUI
import PhotosUI

// MARK: - 客户编辑器 v3（健哥第二轮⑦：新建客户时下方顺便录宠物；①删门禁密码示例）

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

    // 内嵌宠物录入（健哥令⑦：新建客户页下方顺便加宠物）
    @State private var pendingPets: [PendingPet] = []

    struct PendingPet: Identifiable {
        let id = UUID()
        var name = ""
        var type: PetType = .dog
        var breed = ""
        var weight = 10.0
        var groomRecipe = ""
    }

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
                    TextField("家里谁对接？（如：老婆王芳负责收狗/儿子开门）", text: $familyMembers, axis: .vertical)
                        .lineLimit(2...3)
                }
                Section("偏好与备注") {
                    TextField("性格、偏好、注意事项…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                // 内嵌宠物（健哥令⑦）
                Section("宠物（可顺便录入，也可以后再加）") {
                    ForEach($pendingPets) { $pet in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("宠物名字", text: $pet.name)
                                Picker("", selection: $pet.type) {
                                    ForEach(PetType.allCases, id: \.self) { t in
                                        Text("\(t.emoji) \(t.rawValue)").tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 110)
                            }
                            TextField("品种", text: $pet.breed)
                            TextField("美容配方（造型/洗毛精…）", text: $pet.groomRecipe, axis: .vertical)
                                .lineLimit(2...4)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { pendingPets.remove(atOffsets: $0) }
                    Button {
                        pendingPets.append(PendingPet())
                    } label: {
                        Label("加一只宠物", systemImage: "plus.circle")
                    }
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
        name = o.name; phone = o.phone; email = email(o)
        address = o.address; familyMembers = o.familyMembers; notes = o.notes
    }
    private func email(_ o: Owner) -> String { o.email }

    private func save() {
        var savedOwner: Owner
        if var o = existing {
            if let i = data.owners.firstIndex(where: { $0.id == o.id }) {
                o.name = name; o.phone = phone; o.email = self.email(o)
                o.address = address; o.familyMembers = familyMembers; o.notes = notes
                data.owners[i] = o
                savedOwner = o
            } else { return }
        } else {
            let o = Owner(name: name, phone: phone, email: email, address: address,
                          familyMembers: familyMembers, notes: notes)
            data.owners.append(o)
            savedOwner = o
        }
        // 内嵌宠物落库
        for pp in pendingPets where !pp.name.isEmpty {
            data.pets.append(Pet(name: pp.name, type: pp.type, breed: pp.breed, weightKg: pp.weight,
                                 ownerId: savedOwner.id, groomRecipe: pp.groomRecipe))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 通讯录选择器

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
            let email = (contact.emailAddresses.first?.value as String?) ?? ""
            onPick(ContactPickerResult(name: name, phone: phone, email: email))
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onPick(nil)
        }
    }
}

// MARK: - 宠物编辑器 v3（④兔鸟→马 ③时长可选 ⑦喜好+状态 ⑨图片）

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
    @State private var favoriteFood = ""
    @State private var favoritePetting = ""
    @State private var status: PetStatus = .normal
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var hasVaccine = false
    @State private var vaccineExpiry = Date()

    var body: some View {
        NavigationStack {
            Form {
                // 图片（健哥令⑨）
                Section("照片") {
                    HStack {
                        if let d = photoData, let ui = UIImage(data: d) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Button {
                                photoData = nil; photoItem = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("选照片", systemImage: "photo.badge.plus")
                            }
                        }
                    }
                    .onChange(of: photoItem) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                // 压缩到合理尺寸（避免 UserDefaults 爆炸）
                                if let img = UIImage(data: data),
                                   let resized = img.resized(maxSide: 600),
                                   let jpeg = resized.jpegData(compressionQuality: 0.7) {
                                    photoData = jpeg
                                }
                            }
                            photoItem = nil
                        }
                    }
                }
                Section("宠物") {
                    TextField("名字", text: $name)
                    Picker("类型", selection: $type) {
                        ForEach(PetType.allCases, id: \.self) { t in
                            Text("\(t.emoji) \(t.rawValue)").tag(t)
                        }
                    }
                    if type == .other {
                        TextField("填类型（如：刺猬/龙猫/猪）", text: $customType)
                    }
                    TextField("品种", text: $breed)
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
                // 健好令⑦：喜好
                Section("喜好（沟通时讨好它用）") {
                    TextField("喜欢吃什么？（鸡肉冻干/小鱼干…）", text: $favoriteFood)
                    TextField("喜欢怎么摸它？（摸下巴/揉耳朵根…）", text: $favoritePetting)
                }
                Section("脾气") {
                    Picker("咬人风险", selection: $biteLevel) {
                        Text("安全").tag(0)
                        Text("谨慎").tag(1)
                        Text("咬人").tag(2)
                    }
                    .pickerStyle(.segmented)
                    TextField("脾气备注（胆小/认生/需要先遛…）", text: $temperament, axis: .vertical)
                        .lineLimit(2...4)
                }
                // 健哥令⑦：状态标记
                Section("状态") {
                    Picker("当前状态", selection: $status) {
                        ForEach(PetStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                Section("美容配方") {
                    TextField("造型 / 刀头 / 洗毛精备注", text: $groomRecipe, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section("特殊工具携带") {
                    TextField("上门要特别带的工具？（大型犬吹水机/猫嘴套…）", text: $specialTools, axis: .vertical)
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

    private func load() {
        guard let p = existing else {
            ownerId = presetOwnerId ?? data.owners.first?.id
            return
        }
        name = p.name; type = p.type; breed = p.breed; weight = p.weightKg; ownerId = p.ownerId
        temperament = p.temperament; biteLevel = p.biteLevel; groomRecipe = p.groomRecipe
        specialTools = p.specialTools
        favoriteFood = p.favoriteFood; favoritePetting = p.favoritePetting
        status = p.status; photoData = p.photoData
        if let v = p.vaccineExpiry { hasVaccine = true; vaccineExpiry = v }
    }

    private func save() {
        guard let oid = ownerId else { return }
        if var p = existing {
            if let i = data.pets.firstIndex(where: { $0.id == p.id }) {
                p.name = name; p.type = type; p.breed = breed; p.weightKg = weight; p.ownerId = oid
                p.temperament = temperament; p.biteLevel = biteLevel; p.groomRecipe = groomRecipe
                p.specialTools = specialTools
                p.favoriteFood = favoriteFood; p.favoritePetting = favoritePetting
                p.status = status; p.photoData = photoData
                p.vaccineExpiry = hasVaccine ? vaccineExpiry : nil
                data.pets[i] = p
            }
        } else {
            data.pets.append(Pet(name: name, type: type, breed: breed, weightKg: weight, ownerId: oid,
                                 temperament: temperament, biteLevel: biteLevel, groomRecipe: groomRecipe,
                                 specialTools: specialTools, favoriteFood: favoriteFood,
                                 favoritePetting: favoritePetting, status: status, photoData: photoData,
                                 vaccineExpiry: hasVaccine ? vaccineExpiry : nil))
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 预约编辑器 v3（⑥挂主人选宠物；③时长可选；⑩闹钟）

struct AppointmentEditor: View {
    @Binding var data: Store.Data
    let preselectedOwnerId: UUID?
    @Environment(\.dismiss) private var dismiss

    @State private var ownerId: UUID?
    @State private var selectedPetIds: Set<UUID> = []
    @State private var date = Date()
    @State private var minutes = 90
    @State private var buffer = 15
    @State private var remindSelections: [Int] = [60]
    @State private var note = ""

    var ownerPets: [Pet] {
        guard let oid = ownerId else { return [] }
        return data.pets.filter { $0.ownerId == oid }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("客户（预约对象是人）") {
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
                        .onChange(of: ownerId) { nv in
                            // 换客户时清空已选宠物
                            selectedPetIds = []
                            if let p = ownerPets.first { minutes = p.defaultMinutes }
                        }
                    }
                }
                Section("这次服务哪些宠物（可多选）") {
                    if ownerPets.isEmpty {
                        Text("该客户还没有宠物——可在客户详情里加。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(ownerPets) { p in
                            Button {
                                if selectedPetIds.contains(p.id) {
                                    selectedPetIds.remove(p.id)
                                } else {
                                    selectedPetIds.insert(p.id)
                                }
                            } label: {
                                HStack {
                                    Text("\(p.type.emoji) \(p.name)")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedPetIds.contains(p.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                if let oid = ownerId, let owner = data.owners.first(where: { $0.id == oid }),
                   owner.noShowCount > 0 || ownerPets.reduce(0, { $0 + $1.noShowCount }) > 0 {
                    Section {
                        Label("有 \(owner.noShowCount + ownerPets.reduce(0) { $0 + $1.noShowCount }) 次没成功记录——建议收押金",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                Section("时间与时长") {
                    DatePicker("日期与时间", selection: $date)
                    // 健哥令③：美容时长可选（不叫"默认"）
                    Picker("美容时长", selection: $minutes) {
                        Text("45 分钟").tag(45)
                        Text("60 分钟").tag(60)
                        Text("90 分钟").tag(90)
                        Text("120 分钟").tag(120)
                        Text("150 分钟").tag(150)
                        Text("180 分钟").tag(180)
                    }
                    Stepper("车程缓冲 \(buffer) 分钟", value: $buffer, in: 0...60, step: 5)
                }
                // 健哥令⑩-v2：最多三个闹钟，1/2/3/4/6/10小时可选
                Section("提醒（闹钟，最多3个）") {
                    ForEach(remindSelections.indices, id: \.self) { idx in
                        Picker("闹钟 \(idx + 1)", selection: $remindSelections[idx]) {
                            ForEach(Appointment.remindOptions, id: \.self) { mins in
                                Text(label(mins)).tag(mins)
                            }
                        }
                    }
                    if remindSelections.count < 3 {
                        Button {
                            remindSelections.append(120)
                        } label: {
                            Label("加一个闹钟", systemImage: "plus.circle")
                        }
                    }
                    if !remindSelections.isEmpty {
                        Button(role: .destructive) {
                            remindSelections = []
                        } label: {
                            Label("全部清除", systemImage: "trash")
                        }
                    }
                } footer: {
                    Text("到点系统通知提醒你出发。最多设3个，如：提前2小时整理工具 + 提前1小时出发。")
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
                        .disabled(ownerId == nil)
                }
            }
            .onAppear {
                if ownerId == nil {
                    ownerId = preselectedOwnerId ?? data.owners.first?.id
                    if let p = ownerPets.first {
                        minutes = p.defaultMinutes
                        selectedPetIds = [p.id]
                    }
                }
            }
        }
    }

    private func label(_ mins: Int) -> String {
        mins >= 60 ? "提前 \(mins / 60) 小时" : "提前 \(mins) 分钟"
    }

    private func save() {
        guard let oid = ownerId else { return }
        let appt = Appointment(ownerId: oid, petIds: Array(selectedPetIds), date: date,
                               groomMinutes: minutes, driveBufferMinutes: buffer,
                               remindMinutesList: remindSelections, note: note)
        data.appointments.append(appt)
        Store.save(data)
        // 闹钟（健哥令⑩-v2 多闹钟）
        let petNames = data.pets.filter { selectedPetIds.contains($0.id) }.map { $0.name }.joined(separator: "和")
        if let owner = data.owners.first(where: { $0.id == oid }) {
            ReminderScheduler.schedule(appointment: appt, ownerName: owner.name, petNames: petNames)
        }
        dismiss()
    }
}

// MARK: - 反馈页 v3（健哥令⑤：加返回键/导航结构修正）

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
                                    Text("用着哪里不顺？缺什么功能？直接写。")
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 图片缩放工具

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage? {
        let scale = maxSide / max(size.width, size.height)
        if scale >= 1 { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        draw(in: CGRect(origin: .zero, size: newSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}
