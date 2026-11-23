import SwiftUI
import ContactsUI
import PhotosUI
import MessageUI

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

    // 内嵌宠物录入（健哥令⑦：新建客户页下方顺便加宠物；11-21令①：升级完整信息暂存）
    @State private var pendingPets: [Pet] = []
    // 健哥令第七轮③：认领已登记的无主宠物
    @State private var linkedUnownedIds: Set<UUID> = []
    // 健哥11-20令③：家人详细资料（编辑期副本，保存时落库）
    @State private var familyDetail: [FamilyMember] = []
    // 健哥11-21令①：完整宠物表单的弹出与编辑目标
    @State private var addingPet = false
    @State private var editingPendingPet: Pet?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("Name", "姓名"), text: $name)
                    Button {
                        showContactPicker = true
                    } label: {
                        Label(L("Pick from Contacts", "从通讯录选择"), systemImage: "person.crop.rectangle.badge.plus")
                    }
                }
                Section(L("Contact", "联系")) {
                    TextField(L("Phone (tap to call)", "电话（点击可自动拨号）"), text: $phone)
                        .keyboardType(.phonePad)
                    TextField(L("Email", "邮箱"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section(L("Service Address", "上门地址")) {
                    TextField(L("Street / gate / floor (navigate from Today)", "小区/门牌/楼层（首页可导航）"), text: $address, axis: .vertical)
                        .lineLimit(2...3)
                }
                Section(L("Family", "家人")) {
                    TextField(L("Who answers the door?", "家里谁对接？（如：老婆负责收狗/儿子开门）"), text: $familyMembers, axis: .vertical)
                        .lineLimit(2...3)
                    // 健哥11-20令③：右侧进详细资料页（名字/电话/邮箱/照片/注意事项）
                    NavigationLink {
                        FamilyDetailEditor(members: $familyDetail)
                    } label: {
                        HStack {
                            Label(L("Family details", "家人详细资料"), systemImage: "person.crop.rectangle.stack")
                            Spacer()
                            if !familyDetail.isEmpty {
                                Text("\(familyDetail.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section(L("Preferences & Notes", "偏好与备注")) {
                    TextField(L("Temperament, preferences, do-nots…", "性格、偏好、注意事项…"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                // 内嵌宠物（健哥令⑦；11-21令①：宠物页已删，这里升级为完整信息录入——
                // 点"加一只宠物"弹完整 PetEditor 表单：脾气/咬人/喜好/状态/照片/疫苗全都有）
                Section(L("Pets (add now or later)", "宠物（可顺便录入，也可以后再加）")) {
                    ForEach(pendingPets) { pet in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(pet.type.emoji) \(pet.name)")
                                    .font(.headline)
                                HStack(spacing: 6) {
                                    if pet.biteLevel == 2 { Text(L("BITES", "咬人")).font(.caption2).foregroundColor(.red) }
                                    else if pet.biteLevel == 1 { Text(L("care", "谨慎")).font(.caption2).foregroundColor(.orange) }
                                    if !pet.breed.isEmpty { Text(pet.breed).font(.caption2).foregroundColor(.secondary) }
                                    if !pet.temperament.isEmpty { Text(pet.temperament).font(.caption2).foregroundColor(.secondary) }
                                }
                            }
                            Spacer()
                            Button(L("Edit", "改")) {
                                editingPendingPet = pet
                            }
                            .font(.caption)
                        }
                    }
                    .onDelete { pendingPets.remove(atOffsets: $0) }
                    Button {
                        addingPet = true
                    } label: {
                        Label(L("Add a Pet (full details)", "加一只宠物（完整信息）"), systemImage: "plus.circle")
                    }
                }
                // 健哥令第七轮③：已登记宠物选择（有主置灰/无主可认领）
                PetLinkPicker(data: $data, selectedUnownedIds: $linkedUnownedIds, forOwnerId: existing?.id)
            }
            .navigationTitle(existing == nil ? L("New Client", "新建客户") : L("Edit Client", "编辑客户"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "保存")) { save() }
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
            // 健哥11-21令①：完整宠物表单（加新=空表单；编辑=带暂存值）
            .sheet(isPresented: $addingPet) {
                PetEditor(data: $data, existing: nil, presetOwnerId: nil, onPrepared: { pet in
                    pendingPets.append(pet)
                })
            }
            .sheet(item: $editingPendingPet) { pet in
                PetEditor(data: $data, existing: pet, presetOwnerId: nil, onPrepared: { updated in
                    if let i = pendingPets.firstIndex(where: { $0.id == updated.id }) {
                        pendingPets[i] = updated
                    }
                })
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let o = existing else { return }
        name = o.name; phone = o.phone; email = email(o)
        address = o.address; familyMembers = o.familyMembers; notes = o.notes
        familyDetail = o.familyDetail   // 健哥11-20令③：家人详细资料带原值
        // 健哥11-21令①：编辑客户时已有宠物带进暂存列表（可改可删）
        pendingPets = data.pets.filter { $0.ownerId == o.id }
    }
    private func email(_ o: Owner) -> String { o.email }

    private func save() {
        var savedOwner: Owner
        if var o = existing {
            if let i = data.owners.firstIndex(where: { $0.id == o.id }) {
                o.name = name; o.phone = phone; o.email = self.email(o)
                o.address = address; o.familyMembers = familyMembers; o.notes = notes
                o.familyDetail = familyDetail   // 健哥11-20令③
                data.owners[i] = o
                savedOwner = o
            } else { return }
        } else {
            let o = Owner(name: name, phone: phone, email: email, address: address,
                          familyMembers: familyMembers, notes: notes, familyDetail: familyDetail)
            data.owners.append(o)
            savedOwner = o
        }
        // 内嵌宠物落库（11-21令①：完整Pet对象暂存——新增的挂主人；编辑的更新；删掉的移除）
        if let o = existing {
            // 编辑模式：该客户旧宠物里不在 pending 的=被删了
            let pendingIds = Set(pendingPets.map { $0.id })
            data.pets.removeAll { $0.ownerId == o.id && !pendingIds.contains($0.id) }
            for var pp in pendingPets where !pp.name.isEmpty {
                pp.ownerId = savedOwner.id
                if let i = data.pets.firstIndex(where: { $0.id == pp.id }) {
                    data.pets[i] = pp
                } else {
                    data.pets.append(pp)
                }
            }
        } else {
            for var pp in pendingPets where !pp.name.isEmpty {
                pp.ownerId = savedOwner.id
                data.pets.append(pp)
            }
        }
        // 认领的无主宠物改挂本客户（第七轮③）
        for i in data.pets.indices where linkedUnownedIds.contains(data.pets[i].id) {
            data.pets[i].ownerId = savedOwner.id
        }
        Store.save(data)
        dismiss()
    }
}

// MARK: - 家人详细资料页（健哥11-20令③：名字/电话/邮箱/照片/注意事项）
// 顶层页内 NavigationLink 进入，返回自动带回（$binding 直改父状态）。

struct FamilyDetailEditor: View {
    @Binding var members: [FamilyMember]

    var body: some View {
        List {
            ForEach($members) { $m in
                Section {
                    TextField(L("Name (e.g. wife / son…)", "名字（如：老婆/儿子…）"), text: $m.name)
                    TextField(L("Phone", "电话"), text: $m.phone)
                        .keyboardType(.phonePad)
                    TextField(L("Email", "邮箱"), text: $m.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    // 照片（与宠物照片同款压缩纪律：600px/JPEG0.7 防 UserDefaults 爆）
                    HStack {
                        if let d = m.photoData, let ui = UIImage(data: d) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Button(role: .destructive) {
                                m.photoData = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            PhotosPicker(selection: Binding(
                                get: { nil },
                                set: { item in
                                    guard let item else { return }
                                    Task {
                                        if let data = try? await item.loadTransferable(type: Data.self),
                                           let img = UIImage(data: data),
                                           let resized = img.resized(maxSide: 600),
                                           let jpeg = resized.jpegData(compressionQuality: 0.7) {
                                            m.photoData = jpeg
                                        }
                                    }
                                }
                            )) {
                                Label(L("Photo", "照片"), systemImage: "photo.badge.plus")
                            }
                        }
                    }
                    TextField(L("Notes (hard of hearing / only home Wednesdays…)", "注意事项（耳朵背要大声点/只有周三在家…）"), text: $m.note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .onDelete { members.remove(atOffsets: $0) }
            Button {
                members.append(FamilyMember())
            } label: {
                Label(L("Add family member", "加一位家人"), systemImage: "plus.circle")
            }
        }
        .navigationTitle(L("Family Details", "家人详细资料"))
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - 宠物认领选择器（健哥令第七轮③④：新增客户/加宠物时可选择已登记的无主宠物）
// 健哥11-20令⑤：删"已有主人（不可选）"段——新增第二个客户时不再显示其他主人的宠物（看串了），
// 只保留无主宠物认领。

struct PetLinkPicker: View {
    @Binding var data: Store.Data
    /// 本次决定认领的无主宠物 id 集合（父视图保存时改 ownerId）
    @Binding var selectedUnownedIds: Set<UUID>
    /// 正在为哪个客户操作（已属此人的宠物不显示在此，显示在其主人名下）
    let forOwnerId: UUID?

    private var unowned: [Pet] {
        data.pets.filter { $0.ownerId != forOwnerId }.filter { pet in
            // 无主判定：ownerId 在 owners 里找不到对应客户 = 无主（历史遗留/宠物页先建的）
            !data.owners.contains(where: { $0.id == pet.ownerId })
        }
    }

    var body: some View {
        Group {
            // 无主宠物：可选（色深）——其他客户的宠物一律不出现（健哥11-20令⑤）
            if !unowned.isEmpty {
                Section {
                    ForEach(unowned) { pet in
                        Button {
                            if selectedUnownedIds.contains(pet.id) {
                                selectedUnownedIds.remove(pet.id)
                            } else {
                                selectedUnownedIds.insert(pet.id)
                            }
                        } label: {
                            HStack {
                                Text("\(pet.type.emoji) \(pet.name)")
                                    .foregroundColor(.primary)   // 色深=可选
                                Spacer()
                                if selectedUnownedIds.contains(pet.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L("Unregistered owner — link one", "无主宠物——可认领"))
                } footer: {
                    Text(L("These pets have no client yet — select to make this client their owner.", "这些宠物还没归属客户——选中后归到本客户名下。"))
                }
            }
        }
    }
}

// MARK: - 宠物编辑器 v3（④兔鸟→马 ③时长可选 ⑦喜好+状态 ⑨图片）

struct PetEditor: View {
    @Binding var data: Store.Data
    let existing: Pet?
    let presetOwnerId: UUID?
    /// 健哥11-21令①：ClientEditor 场景回调——"保存"不直接落库，把完整 Pet 交回父视图暂存
    var onPrepared: ((Pet) -> Void)? = nil
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
    // 健哥令第七轮④：客户详情/宠物页加宠物时，可改为认领无主宠物（选中后本表单只做认领）
    @State private var claimUnownedId: UUID?
    // 健哥11-20令③：内联新建客户（宠物页直接把主人顺手填了——合成一页）
    @State private var newOwnerName = ""
    @State private var newOwnerPhone = ""

    /// 全库无主宠物（ownerId 无对应客户）
    private var unownedPets: [Pet] {
        guard existing == nil else { return [] }   // 编辑已有宠物时不出现认领
        return data.pets.filter { pet in
            pet.ownerId != presetOwnerId && !data.owners.contains(where: { $0.id == pet.ownerId })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 健哥令第七轮④：先选——认领已有的无主宠物（选中即跳过新建表单）
                // （11-21令①：ClientEditor暂存模式下不出现——主人未定，认领无意义）
                if onPrepared == nil && !unownedPets.isEmpty {
                    Section {
                        ForEach(unownedPets) { pet in
                            Button {
                                claimUnownedId = (claimUnownedId == pet.id) ? nil : pet.id
                            } label: {
                                HStack {
                                    Text("\(pet.type.emoji) \(pet.name)")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if claimUnownedId == pet.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(L("Link a registered pet (no owner)", "认领已登记的无主宠物"))
                    } footer: {
                        Text(L("Selecting a pet above will re-link it to this client instead of creating a new one (fill the owner below).", "选中上面的宠物后保存=把它归到所选客户名下，不再新建。"))
                    }
                }
                // 图片（健哥令⑨）
                Section(L("Photo", "照片")) {
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
                                Label(L("Choose Photo", "选照片"), systemImage: "photo.badge.plus")
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
                Section(L("Pet", "宠物")) {
                    TextField(L("Name", "名字"), text: $name)
                    Picker(L("Type", "类型"), selection: $type) {
                        ForEach(PetType.allCases, id: \.self) { t in
                            Text("\(t.emoji) \(t.display)").tag(t)
                        }
                    }
                    if type == .other {
                        TextField(L("Type (hedgehog / chinchilla / pig…)", "填类型（如：刺猬/龙猫/猪）"), text: $customType)
                    }
                    TextField(L("Breed", "品种"), text: $breed)
                }
                if onPrepared == nil {
                Section(L("Owner", "主人")) {
                    if data.owners.isEmpty && newOwnerName.isEmpty {
                        // 健哥11-20令③：没客户不必跳页——本页直接顺手建（一页填完主人和宠物）
                        Text(L("No client yet — create one right here:", "还没有客户——直接在这里建："))
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                    if !data.owners.isEmpty || !newOwnerName.isEmpty {
                        Picker(L("Client", "客户"), selection: $ownerId) {
                            ForEach(data.owners) { o in
                                Text(o.name).tag(Optional(o.id))
                            }
                        }
                    }
                    // 健哥11-20令③：内联新建客户（合成一页——填了名字保存时自动建客户并挂给它）
                    if !data.owners.isEmpty {
                        Text(L("or create a new client:", "或新建客户："))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField(L("New client name (phone optional)", "新客户姓名（电话可填可不填）"), text: $newOwnerName)
                    if !newOwnerName.isEmpty {
                        TextField(L("Phone (optional)", "电话（可选）"), text: $newOwnerPhone)
                            .keyboardType(.phonePad)
                    }
                }
                }
                // 健好令⑦：喜好
                Section(L("Favorites (rapport)", "喜好（沟通时讨好它用）")) {
                    TextField(L("Favorite treats? (chicken jerky / fish snacks…)", "喜欢吃什么？（鸡肉冻干/小鱼干…）"), text: $favoriteFood)
                    TextField(L("Where to pet? (chin rubs / ear scratches…)", "喜欢怎么摸它？（摸下巴/揉耳朵根…）"), text: $favoritePetting)
                }
                Section(L("Temperament", "脾气")) {
                    Picker(L("Bite risk", "咬人风险"), selection: $biteLevel) {
                        Text(L("Safe", "安全")).tag(0)
                        Text(L("Care", "谨慎")).tag(1)
                        Text(L("Bites", "咬人")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    TextField(L("Notes (shy / wary / needs a walk first…)", "脾气备注（胆小/认生/需要先遛…）"), text: $temperament, axis: .vertical)
                        .lineLimit(2...4)
                }
                // 健哥令⑦：状态标记
                Section(L("Status", "状态")) {
                    Picker(L("Current status", "当前状态"), selection: $status) {
                        ForEach(PetStatus.allCases, id: \.self) { s in
                            Text(s.display).tag(s)
                        }
                    }
                }
                Section(L("Grooming Recipe", "美容配方")) {
                    TextField(L("Style / blade / shampoo notes", "造型 / 刀头 / 洗毛精备注"), text: $groomRecipe, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section(L("Special Tools to Bring", "特殊工具携带")) {
                    TextField(L("Special tools to bring? (dryer / muzzle…)", "上门要特别带的工具？（大型犬吹水机/猫嘴套…）"), text: $specialTools, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section(L("Vaccine", "疫苗")) {
                    Toggle(L("Track vaccine expiry", "记录疫苗到期"), isOn: $hasVaccine)
                    if hasVaccine {
                        DatePicker(L("Expires", "到期日"), selection: $vaccineExpiry, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(existing == nil ? L("New Pet", "新建宠物") : L("Edit Pet", "编辑宠物"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "保存")) { save() }
                        .disabled(name.isEmpty || (onPrepared == nil && ownerId == nil && newOwnerName.trimmingCharacters(in: .whitespaces).isEmpty))
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
        // 健哥11-21令①：ClientEditor 场景——不落库，把完整 Pet 交回父视图暂存
        // （主人还没保存，此刻落库会挂错人；统一等 ClientEditor.save() 落）
        if let cb = onPrepared {
            let petId = existing?.id ?? UUID()
            let p = Pet(id: petId, name: name, type: type, breed: breed, weightKg: weight,
                        ownerId: presetOwnerId ?? UUID(), temperament: temperament, biteLevel: biteLevel,
                        groomRecipe: groomRecipe, specialTools: specialTools, favoriteFood: favoriteFood,
                        favoritePetting: favoritePetting, status: status, photoData: photoData,
                        vaccineExpiry: hasVaccine ? vaccineExpiry : nil)
            cb(p)
            dismiss()
            return
        }
        // 健哥11-20令③：内联新建客户——填了新客户名就先建客户，宠物直接挂它（合成一页）
        var oid: UUID
        if !newOwnerName.trimmingCharacters(in: .whitespaces).isEmpty {
            let o = Owner(name: newOwnerName.trimmingCharacters(in: .whitespaces),
                          phone: newOwnerPhone.trimmingCharacters(in: .whitespaces))
            data.owners.append(o)
            oid = o.id
        } else {
            guard let existingOid = ownerId else { return }
            oid = existingOid
        }
        // 健哥令第七轮④：认领模式——把无主宠物改挂所选客户，不新建
        if let claimId = claimUnownedId,
           let i = data.pets.firstIndex(where: { $0.id == claimId }) {
            data.pets[i].ownerId = oid
            Store.save(data)
            dismiss()
            return
        }
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
    var editing: Appointment? = nil    // 健哥令第五轮①：编辑模式（带原值）
    @Environment(\.dismiss) private var dismiss

    @State private var ownerId: UUID?
    @State private var selectedPetIds: Set<UUID> = []
    @State private var date = Date()
    @State private var minutes = 90
    @State private var buffer = 15
    // 健哥11-20令⑤：三种闹钟（用户自由设时间点）——旧"提前X小时"预设废弃
    @State private var hasPrepAlarm = false
    @State private var prepAlarm = Date()
    @State private var hasDepartAlarm = false
    @State private var departAlarm = Date()
    @State private var hasEndAlarm = false
    @State private var endAlarm = Date()
    @State private var note = ""
    @State private var loaded = false

    var ownerPets: [Pet] {
        guard let oid = ownerId else { return [] }
        return data.pets.filter { $0.ownerId == oid }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("Client (people first)", "客户（预约对象是人）")) {
                    if data.owners.isEmpty {
                        Text(L("Add a client first (Clients tab).", "请先在「客户」页添加客户。"))
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        // 健哥令第七轮⑤：换客户时宠物列表必须跟随——自定义 Binding 在 set 时同步清选，
                        // 不依赖 onChange 时序（iOS16 单参签名换值偶发不触发）
                        Picker(L("Client", "客户"), selection: Binding(
                            get: { ownerId },
                            set: { nv in
                                let changed = nv != ownerId
                                ownerId = nv
                                if changed {
                                    selectedPetIds = []
                                    if let oid = nv,
                                       let p = data.pets.first(where: { $0.ownerId == oid }) {
                                        minutes = p.defaultMinutes
                                    }
                                }
                            }
                        )) {
                            ForEach(data.owners) { o in
                                Text(o.name).tag(Optional(o.id))
                            }
                        }
                    }
                }
                Section(L("Pets for this visit (multi-select)", "这次服务哪些宠物（可多选）")) {
                    if ownerPets.isEmpty {
                        Text(L("No pets yet — add from the client page.", "该客户还没有宠物——可在客户详情里加。"))
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
                        Label(L10n.noShowWarn(owner.noShowCount + ownerPets.reduce(0) { $0 + $1.noShowCount }),
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                Section(L("Time & Duration", "时间与时长")) {
                    DatePicker(L("Date & time", "日期与时间"), selection: $date)
                    // 健哥令③：美容时长可选（不叫"默认"）
                    Picker(L("Groom duration", "美容时长"), selection: $minutes) {
                        Text(L("45 min", "45 分钟")).tag(45)
                        Text(L("60 min", "60 分钟")).tag(60)
                        Text(L("90 min", "90 分钟")).tag(90)
                        Text(L("120 min", "120 分钟")).tag(120)
                        Text(L("150 min", "150 分钟")).tag(150)
                        Text(L("180 min", "180 分钟")).tag(180)
                    }
                    Stepper(L("Drive buffer \(buffer) min", "车程缓冲 \(buffer) 分钟"), value: $buffer, in: 0...60, step: 5)
                }
                // 健哥11-20令⑤：三种闹钟（开/关+自由设时间）——锁屏标题就是闹钟名
                Section {
                    Toggle(L("Start-prep reminder", "开始准备提醒"), isOn: $hasPrepAlarm)
                    if hasPrepAlarm {
                        DatePicker(L("Prep alarm", "闹钟时间"), selection: $prepAlarm)
                    }
                    Toggle(L("Latest departure time", "最晚出发时间"), isOn: $hasDepartAlarm)
                    if hasDepartAlarm {
                        DatePicker(L("Depart alarm", "闹钟时间"), selection: $departAlarm)
                    }
                    Toggle(L("End-of-service reminder", "提醒结束时间"), isOn: $hasEndAlarm)
                    if hasEndAlarm {
                        DatePicker(L("End alarm", "闹钟时间"), selection: $endAlarm)
                    }
                } header: {
                    Text(L("Alarms", "闹钟"))
                } footer: {
                    Text(L("Turn on what you need and set any time. Alarm names show on your Lock Screen, e.g. \"Start-prep reminder\".", "要哪个开哪个，时间自由设。闹钟响时锁屏显示名称，如「准备出发提醒」。"))
                }
                Section(L("Notes", "备注")) {
                    TextField(L("Note (optional)", "备注（可选）"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(L("New Appointment", "新建预约"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Save", "保存")) { save() }
                        .disabled(ownerId == nil)
                }
            }
            .onAppear {
                // 健哥令第五轮①：编辑模式带原值
                if let appt = editing, !loaded {
                    ownerId = appt.ownerId
                    selectedPetIds = Set(appt.petIds)
                    date = appt.date
                    minutes = appt.groomMinutes
                    buffer = appt.driveBufferMinutes
                    // 健哥11-20令⑤：三闹钟带原值（旧数据无闹钟=旧分钟数换算成出发闹钟）
                    if let p = appt.prepAlarm { hasPrepAlarm = true; prepAlarm = p }
                    if let d = appt.departAlarm { hasDepartAlarm = true; departAlarm = d }
                    else if let legacy = appt.remindMinutesList.first {
                        // 旧"提前60分钟"迁移：换算成绝对时间挂到出发闹钟（不打丢用户旧设置）
                        hasDepartAlarm = true
                        departAlarm = appt.date.addingTimeInterval(-Double(legacy) * 60)
                    }
                    if let e = appt.endAlarm { hasEndAlarm = true; endAlarm = e }
                    note = appt.note
                    loaded = true
                } else if ownerId == nil {
                    ownerId = preselectedOwnerId ?? data.owners.first?.id
                    if let p = ownerPets.first {
                        minutes = p.defaultMinutes
                        selectedPetIds = [p.id]
                    }
                    // 新建默认：最晚出发=预约前车程缓冲
                    hasDepartAlarm = true
                    departAlarm = date.addingTimeInterval(-Double(buffer) * 60)
                }
            }
        }
    }

    private func save() {
        guard let oid = ownerId else { return }
        let appt = Appointment(id: editing?.id ?? UUID(), ownerId: oid, petIds: Array(selectedPetIds), date: date,
                               groomMinutes: minutes, driveBufferMinutes: buffer,
                               remindMinutesList: [],
                               prepAlarm: hasPrepAlarm ? prepAlarm : nil,
                               departAlarm: hasDepartAlarm ? departAlarm : nil,
                               endAlarm: hasEndAlarm ? endAlarm : nil,
                               status: editing?.status ?? .scheduled, note: note)

        if let editing, let idx = data.appointments.firstIndex(where: { $0.id == editing.id }) {
            data.appointments[idx] = appt    // 健哥令第五轮①：更新而非追加
        } else {
            data.appointments.append(appt)
        }
        Store.save(data)
        // 闹钟（健哥令⑩-v2 多闹钟；编辑后重排）
        ReminderScheduler.schedule(appointment: appt,
                                   ownerName: data.owners.first(where: { $0.id == oid })?.name ?? "",
                                   petNames: data.pets.filter { selectedPetIds.contains($0.id) }.map { $0.name }.joined(separator: AppLang.current == .en ? " & " : "和"))
        dismiss()
    }
}

// MARK: - 反馈页 v4（健哥令第七轮：①返回=tab结构可切走+顶部说明 ⑦道歉文案 ①%20根修=MessageUI原生邮件）
// %20 根因：mail body 走 URL percent-encoding，邮件 App 把转义序列当字面显示。
// 根修=MFMailComposeViewController 原生邮件草稿，正文直传字符串零转义。
// （import MessageUI 已在文件顶部——CI 教训：import 不能放文件中段）

struct FeedbackView: View {
    /// 重看新手引导回调（健哥 11-19 令：Me 页入口）
    var replayOnboarding: (() -> Void)? = nil
    /// 返回键回调（健哥 11-21 令②：右上角返回——Tab 根页用切 Tab 实现"返回"）
    var onBack: (() -> Void)? = nil
    @State private var feedbackText = ""
    // 11-24试用制测试钩子：版本行连点5下唤出调试区（TestFlight可测到期/解锁状态）
    @State private var versionTaps = 0
    @State private var showTrialDebug = false
    @State private var debugTick = 0   // 覆盖切换后强制刷新显示
    // 🔴健哥11-21令复查破案：同 view 挂两个 sheet(isPresented:) 只有最后一个生效（SwiftUI 已知限制）
    // ——showMail 的 sheet 被 mailUnavailable 的 sheet 覆盖注册，有系统邮件账户时点按钮没反应。
    // 根修：合并成一个 sheet(item:)（枚举两态），永不冲突。
    private enum MailFlow: Identifiable {
        case composer      // 有系统邮件账户→原生邮件草稿
        case noAccount     // 无账户→提示页（正文已复制+邮箱地址）
        var id: String { switch self { case .composer: return "composer"; case .noAccount: return "noAccount" } }
    }
    @State private var mailFlow: MailFlow?

    var body: some View {
        NavigationStack {
        Form {
            Section(L("Feedback", "反馈意见")) {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 120)
                    .overlay(
                        Group {
                            if feedbackText.isEmpty {
                                Text(L("What is clunky? What is missing? Just write it.", "用着哪里不顺？缺什么功能？直接写。"))
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                    )
                    // 健哥11-20令②：键盘收不掉根修——键盘上沿加"完成"键一键收起
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                Label(L("Done", "完成"), systemImage: "keyboard.chevron.compact.down")
                            }
                        }
                    }
            }
            Section {
                Button {
                    if MFMailComposeViewController.canSendMail() {
                        mailFlow = .composer
                    } else {
                        // 健哥11-21令：无系统邮件账户时不跳 mailto（白屏像没反应）——
                        // 弹明确提示：正文已复制+邮箱地址，用户去任意邮件App发
                        UIPasteboard.general.string = feedbackText
                        mailFlow = .noAccount
                    }
                } label: {
                    Label(L("Send Feedback by Email", "发送反馈（走你的邮件）"), systemImage: "paperplane.fill")
                }
                .disabled(feedbackText.isEmpty)
            } header: {
                Text(L("Me", "我的"))
            } footer: {
                // 健哥令第七轮⑦：道歉+欢迎新功能想法（上架英文版）
                Text(L("Sorry for any trouble! Please tell the developer what's not working — it will be fixed as soon as possible. New feature ideas are also very welcome, so the app can serve you better.\n\nFeedback goes straight to the developer by email. Nothing is stored in the app. To go back, just switch tabs at the bottom.",
                       "若有使用不便十分抱歉，请把具体问题反馈给开发者，会尽快修改。若有新功能想法，也可以告知，让开发者更好服务。\n\n反馈通过邮件直达开发者，不留任何数据在 App 里。返回请点底部标签切换。"))
            }
            // 11-24试用制：状态行（试用倒计时/到期只读/已解锁；到期点它=弹付费墙）
            Section {
                Button {
                    if !TrialStore.canWrite {
                        NotificationCenter.default.post(name: TrialStore.showPaywallNotification, object: nil)
                    }
                } label: {
                    HStack {
                        Label(L("GroomerBook Pro", "GroomerBook Pro"),
                              systemImage: (ProStore.unlocked || TrialStore.debugOverride == "unlocked") ? "crown.fill" : (TrialStore.canWrite ? "hourglass" : "lock"))
                            .foregroundColor(.orange)
                        Spacer()
                        Text(TrialStore.statusText)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(L("Pro", "Pro"))
            } footer: {
                Text(L("30-day full-feature trial. After it ends: records stay readable & exportable free forever; unlock once to keep adding.",
                       "30天全功能试用。到期后：记录永远可看可导出（免费）；解锁一次即可继续新增。"))
                    .font(.caption2)
            }
            // 健哥 11-19 令：新手引导重看入口
            Section {
                Button {
                    replayOnboarding?()
                } label: {
                    Label(L("Replay the beginner's guide", "重看新手引导"), systemImage: "questionmark.circle")
                }
            } header: {
                Text(L("Help", "帮助"))
            } footer: {
                Text(L("New here? A 4-step quick tour of Today, Clients, Pets and booking.", "第一次用？4步快速过一遍今日/客户/宠物/约单。"))
            }
            // 11-24测试钩子：版本行连点5下唤出试用状态调试（健哥TestFlight实测用，普通用户无感）
            Section {
                Button {
                    versionTaps += 1
                    if versionTaps >= 5 { showTrialDebug.toggle(); versionTaps = 0 }
                } label: {
                    HStack {
                        Text(L("Version", "版本")).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                if showTrialDebug {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("调试：试用状态覆盖（仅测试用，切换后切个Tab刷新横幅）").font(.caption.bold())
                        Text("起点：\(TrialStore.startDate.map { "\($0)" } ?? "未登记")｜剩 \(TrialStore.daysLeft) 天｜覆盖：\(TrialStore.debugOverride ?? "无")")
                            .font(.caption2).foregroundColor(.secondary)
                        Button("重置为全新试用（30天）") { TrialStore.setDebugOverride("fresh"); debugTick += 1 }
                        Button("强制到期（只读+导出免费）") { TrialStore.setDebugOverride("expired"); debugTick += 1 }
                        Button("强制已解锁") { TrialStore.setDebugOverride("unlocked"); debugTick += 1 }
                        Button("清除覆盖（恢复真实状态）") { TrialStore.setDebugOverride(nil); debugTick += 1 }
                    }
                    .font(.caption)
                    .id(debugTick)   // 覆盖切换→整个body重算→状态行同步刷新
                }
            }
        }
        // 🔴健哥11-21令复查根修：两个 sheet(isPresented:) 挂同一 view 只有最后一个生效——
        // 合并成单 sheet(item:)（MailFlow 两态），有账户/无账户都有明确反应
        .sheet(item: $mailFlow) { flow in
            switch flow {
            case .composer:
                MailComposer(
                    to: "zerone348@gmail.com",
                    subject: "GroomerBook Feedback",
                    body: feedbackText
                )
                .ignoresSafeArea()
            case .noAccount:
                // 无邮件账户的明确出口（正文已复制+邮箱地址可长按复制，去任意邮件App发）
                NavigationStack {
                    Form {
                        Section {
                            Text(L("No system Mail account on this phone, so the draft can't open here.", "本机没配系统邮件账户，草稿打不开。"))
                                .font(.subheadline)
                            Text(L("Your feedback has been copied. Send it from any mail app (QQ Mail / Gmail / Outlook) to:", "你的反馈文字已复制。请在任意邮件App（QQ邮箱/Gmail/Outlook）里粘贴发给："))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("zerone348@gmail.com")
                                .font(.body.bold())
                                .textSelection(.enabled)
                        } footer: {
                            Text(L("Long-press the address above to copy it.", "长按上面地址可复制。"))
                        }
                    }
                    .navigationTitle(L("Email the Developer", "邮件发给开发者"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L("Done", "完成")) { mailFlow = nil }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        // 健哥11-20令②：收键盘——🔴11-21二次修正（返工）：
        // onTapGesture 吞 Button（一次修）→ simultaneousGesture 仍与 Form 滚动/按钮竞争（健哥再实锤）。
        // 根治=彻底删全局手势，只留苹果官方两通道：①键盘"完成"键（上面 toolbar 已有）
        // ②scrollDismissesKeyboard 滚动即收。多一手势都是祸。
        .scrollDismissesKeyboard(.immediately)
        // 健哥11-21令②：右上角返回键（Tab根页无系统返回——用onBack切回Today）
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onBack?()
                } label: {
                    Label(L("Back", "返回"), systemImage: "chevron.left.circle.fill")
                }
            }
        }
        .navigationTitle(L("Feedback", "反馈"))
        .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 系统邮件编辑器（正文原生直传，零 %20 转义）
struct MailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([to])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
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
