import Foundation

// MARK: - 数据模型 v3（健哥第二轮10条测试反馈：
// ③美容时长可选 ④兔鸟→马 ⑥预约挂主人 ⑦宠物状态标记+喜好 ⑧导出 ⑨图片 ⑩闹钟）

enum PetType: String, Codable, CaseIterable {
    case dog = "狗"
    case cat = "猫"
    case horse = "马"
    case other = "其他"

    var emoji: String {
        switch self { case .dog: return "🐕"; case .cat: return "🐈"; case .horse: return "🐎"; case .other: return "🐾" }
    }
}

/// 宠物状态（健哥令⑦：可标记生病/死亡/残疾/离开）
enum PetStatus: String, Codable, CaseIterable {
    case normal = "正常"
    case sick = "生病"
    case disabled = "残疾"
    case left = "离开（换美容师/搬家）"
    case passed = "去世 💔"

    var color: String {
        switch self { case .normal: return "primary"; case .sick: return "orange"; case .disabled: return "blue"; case .left: return "gray"; case .passed: return "gray" }
    }
}

struct Owner: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var phone: String
    var email: String
    var address: String
    var familyMembers: String
    var notes: String             // 偏好备注（健哥令①：已删门禁密码示例）
    var noShowCount: Int

    init(id: UUID = UUID(), name: String, phone: String = "", email: String = "", address: String = "",
         familyMembers: String = "", notes: String = "", noShowCount: Int = 0) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.familyMembers = familyMembers
        self.notes = notes
        self.noShowCount = noShowCount
    }
}

struct Pet: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: PetType
    var breed: String
    var weightKg: Double
    var ownerId: UUID
    var temperament: String       // 脾气（健哥令②：已删"怕猫"示例）
    var biteLevel: Int            // 0=安全 1=谨慎 2=咬人
    var groomRecipe: String       // 美容配方
    var specialTools: String      // 特殊工具携带
    var favoriteFood: String      // 健哥令⑦：喜欢吃什么
    var favoritePetting: String   // 健哥令⑦：喜欢怎么摸它
    var status: PetStatus         // 健哥令⑦：生病/死亡/残疾/离开
    var photoData: Data?          // 健哥令⑨：宠物照片
    var vaccineExpiry: Date?
    var noShowCount: Int

    init(id: UUID = UUID(), name: String, type: PetType = .dog, breed: String = "", weightKg: Double = 10,
         ownerId: UUID, temperament: String = "", biteLevel: Int = 0, groomRecipe: String = "",
         specialTools: String = "", favoriteFood: String = "", favoritePetting: String = "",
         status: PetStatus = .normal, photoData: Data? = nil, vaccineExpiry: Date? = nil, noShowCount: Int = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.breed = breed
        self.weightKg = weightKg
        self.ownerId = ownerId
        self.temperament = temperament
        self.biteLevel = biteLevel
        self.groomRecipe = groomRecipe
        self.specialTools = specialTools
        self.favoriteFood = favoriteFood
        self.favoritePetting = favoritePetting
        self.status = status
        self.photoData = photoData
        self.vaccineExpiry = vaccineExpiry
        self.noShowCount = noShowCount
    }

    var defaultMinutes: Int {
        let base: Int
        switch weightKg {
        case ..<8: base = 60
        case ..<20: base = 90
        case ..<35: base = 120
        default: base = 150
        }
        return type == .cat ? max(45, base - 15) : base
    }
}

struct Appointment: Codable, Identifiable, Equatable {
    let id: UUID
    var ownerId: UUID             // 健哥令⑥：预约挂主人（不是宠物）——上门服务对象是人
    var petIds: [UUID]            // 这次上门服务哪些宠物（一户可能多只一起）
    var date: Date
    var groomMinutes: Int         // 美容时长（健哥令③：可选，不叫"默认"）
    var driveBufferMinutes: Int
    var remindMinutesBefore: Int  // 健哥令⑩：提前提醒（分钟；0=不提醒）
    var status: Status
    var note: String

    enum Status: String, Codable {
        case scheduled = "已约"
        case done = "已完成"
        case noshow = "没成功"
        case canceled = "已取消"
    }

    init(id: UUID = UUID(), ownerId: UUID, petIds: [UUID] = [], date: Date, groomMinutes: Int,
         driveBufferMinutes: Int = 15, remindMinutesBefore: Int = 60, status: Status = .scheduled, note: String = "") {
        self.id = id
        self.ownerId = ownerId
        self.petIds = petIds
        self.date = date
        self.groomMinutes = groomMinutes
        self.driveBufferMinutes = driveBufferMinutes
        self.remindMinutesBefore = remindMinutesBefore
        self.status = status
        self.note = note
    }

    static let reorderDays = 42
}

// MARK: - 存储 v3（v1/v2 自动迁移）

enum Store {
    static let key = "groomerbook.data.v3"

    struct Data: Codable {
        var owners: [Owner] = []
        var pets: [Pet] = []
        var appointments: [Appointment] = []
    }

    static func load() -> Data {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let d = try? JSONDecoder().decode(Data.self, from: raw) else {
            return migrateV2() ?? Data()
        }
        return d
    }

    /// v2（预约挂petId单宠物）→ v3（预约挂ownerId+petIds数组）
    private static func migrateV2() -> Data? {
        guard let raw = UserDefaults.standard.data(forKey: "groomerbook.data.v2"),
              let old = try? JSONDecoder().decode(OldV2.self, from: raw) else { return nil }
        var d = Data()
        d.owners = old.owners
        d.pets = old.pets
        // 旧预约：petId→ownerId+petIds
        d.appointments = old.appointments.map { ap in
            let ownerId = old.pets.first(where: { $0.id == ap.petId })?.ownerId ?? UUID()
            return Appointment(id: ap.id, ownerId: ownerId, petIds: [ap.petId], date: ap.date,
                               groomMinutes: ap.groomMinutes, driveBufferMinutes: ap.driveBufferMinutes,
                               remindMinutesBefore: 60, status: ap.status, note: ap.note)
        }
        if let raw2 = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(raw2, forKey: key)
        }
        return d
    }

    private struct OldV2: Codable {
        var owners: [Owner]
        var pets: [Pet]
        var appointments: [OldAppt]
    }

    private struct OldAppt: Codable {
        let id: UUID; var petId: UUID; var date: Date; var groomMinutes: Int
        var driveBufferMinutes: Int; var status: Appointment.Status; var note: String
    }

    static func save(_ d: Data) {
        if let raw = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}

// MARK: - 快捷短信模板

enum MessageTemplate {
    static func onMyWay(owner: Owner, pets: [Pet], minutes: Int) -> String {
        let names = pets.map { $0.name }.joined(separator: "和")
        return "\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \(minutes) 分钟后到，请把\(names)准备好、门能开。"
    }
}

// MARK: - 导出（健哥令⑧：单客户/全量导出成文件）

enum Exporter {
    /// 生成导出文本（单客户带宠物+预约；全量=全部）
    static func makeText(data: Store.Data, ownerFilter: UUID? = nil) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.locale = Locale(identifier: "zh_CN")
        var lines: [String] = []
        let owners = ownerFilter.map { data.owners.filter { $0.id == $0 } } ?? data.owners

        lines.append("宠物美容台账 导出 · \(df.string(from: Date()))")
        lines.append(String(repeating: "=", count: 40))
        for owner in owners {
            lines.append("")
            lines.append("【客户】\(owner.name)")
            if !owner.phone.isEmpty { lines.append("电话：\(owner.phone)") }
            if !owner.email.isEmpty { lines.append("邮箱：\(owner.email)") }
            if !owner.address.isEmpty { lines.append("地址：\(owner.address)") }
            if !owner.familyMembers.isEmpty { lines.append("家人：\(owner.familyMembers)") }
            if !owner.notes.isEmpty { lines.append("备注：\(owner.notes)") }
            let pets = data.pets.filter { $0.ownerId == owner.id }
            if !pets.isEmpty {
                lines.append("-- 宠物（\(pets.count)）--")
                for p in pets {
                    var l = "\(p.type.emoji) \(p.name)（\(p.type.rawValue)·\(p.breed)·\(p.status.rawValue)）"
                    if p.biteLevel > 0 { l += " 咬人风险:\(["安全","谨慎","咬人"][p.biteLevel])" }
                    lines.append(l)
                    if !p.groomRecipe.isEmpty { lines.append("  配方：\(p.groomRecipe)") }
                    if !p.specialTools.isEmpty { lines.append("  特殊工具：\(p.specialTools)") }
                    if !p.favoriteFood.isEmpty { lines.append("  爱吃：\(p.favoriteFood)") }
                    if !p.favoritePetting.isEmpty { lines.append("  爱摸：\(p.favoritePetting)") }
                    if !p.temperament.isEmpty { lines.append("  脾气：\(p.temperament)") }
                }
            }
            let appts = data.appointments.filter { $0.ownerId == owner.id }.sorted { $0.date > $1.date }
            if !appts.isEmpty {
                lines.append("-- 上门记录（\(appts.count)）--")
                for a in appts {
                    let petNames = a.petIds.compactMap { id in data.pets.first { $0.id == id }?.name }.joined(separator: "和")
                    lines.append("  \(df.string(from: a.date)) \(petNames) \(a.status.rawValue) \(a.groomMinutes)分钟")
                }
            }
        }
        if ownerFilter == nil {
            lines.append("")
            lines.append(String(repeating: "=", count: 40))
            lines.append("合计：客户\(data.owners.count) · 宠物\(data.pets.count) · 上门\(data.appointments.count)次")
        }
        return lines.joined(separator: "\n")
    }
}
