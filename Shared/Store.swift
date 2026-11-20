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

    /// 显示值（上架英文版健哥令：AppLang 控制）
    var display: String {
        AppLang.current == .en
            ? ["Dog", "Cat", "Horse", "Other"][index]
            : rawValue
    }

    private var index: Int {
        switch self { case .dog: return 0; case .cat: return 1; case .horse: return 2; case .other: return 3 }
    }
}

/// 宠物状态（健哥令⑦：可标记生病/死亡/残疾/离开）
enum PetStatus: String, Codable, CaseIterable {
    case normal = "正常"
    case sick = "生病"
    case disabled = "残疾"
    case left = "离开（换美容师/搬家）"
    case passed = "去世 💔"

    /// 显示值（上架英文版）
    var display: String {
        switch self {
        case .normal: return L("Normal", "正常")
        case .sick: return L("Sick", "生病")
        case .disabled: return L("Disabled", "残疾")
        case .left: return L("Left (moved / switched groomer)", "离开（换美容师/搬家）")
        case .passed: return L("Passed away 💔", "去世 💔")
        }
    }

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
    var familyDetail: [FamilyMember] = []   // 健哥11-20令③：家人详细资料（名字/电话/邮箱/照片/注意事项）

    init(id: UUID = UUID(), name: String, phone: String = "", email: String = "", address: String = "",
         familyMembers: String = "", notes: String = "", noShowCount: Int = 0,
         familyDetail: [FamilyMember] = []) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.familyMembers = familyMembers
        self.notes = notes
        self.noShowCount = noShowCount
        self.familyDetail = familyDetail
    }
}

/// 家人成员（健哥11-20令③：new client 的 family 字段右侧可进详细资料页）
struct FamilyMember: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var note: String = ""         // 注意事项（如：耳朵背要大声点/只有周三在家）
    var photoData: Data? = nil
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
    var remindMinutesList: [Int]  // 旧版字段（v0.2前）：保留解码兼容，新版用下面三个闹钟
    // 健哥11-20令⑤：三种闹钟（用户自由设时间点，不再是"提前X小时"预设）
    var prepAlarm: Date?          // 开始准备提醒（如：提前2小时收拾工具箱）
    var departAlarm: Date?        // 最晚出发时间（路上车程+缓冲的底线）
    var endAlarm: Date?           // 提醒结束时间（预计服务完的时间点）
    var status: Status
    var note: String

    enum Status: String, Codable {
        case scheduled = "已约"
        case done = "已完成"
        case noshow = "没成功"
        case canceled = "已取消"

        /// 显示值（上架英文版）
        var display: String {
            switch self {
            case .scheduled: return L("Scheduled", "已约")
            case .done: return L("Done", "已完成")
            case .noshow: return L("No-show", "没成功")
            case .canceled: return L("Canceled", "已取消")
            }
        }
    }

    init(id: UUID = UUID(), ownerId: UUID, petIds: [UUID] = [], date: Date, groomMinutes: Int,
         driveBufferMinutes: Int = 15, remindMinutesList: [Int] = [60],
         prepAlarm: Date? = nil, departAlarm: Date? = nil, endAlarm: Date? = nil,
         status: Status = .scheduled, note: String = "") {
        self.id = id
        self.ownerId = ownerId
        self.petIds = petIds
        self.date = date
        self.groomMinutes = groomMinutes
        self.driveBufferMinutes = driveBufferMinutes
        self.remindMinutesList = Array(remindMinutesList.prefix(3))   // 最多3个
        self.prepAlarm = prepAlarm
        self.departAlarm = departAlarm
        self.endAlarm = endAlarm
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
                               remindMinutesList: [60], status: ap.status, note: ap.note)
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
        let sep = AppLang.current == .en ? " & " : "和"
        let names = pets.map { $0.name }.joined(separator: sep)
        if AppLang.current == .en {
            return "Hi \(owner.name), this is your groomer - on my way now for \(names), about \(minutes) min out. Please have them ready and the gate accessible."
        }
        return "\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \(minutes) 分钟后到，请把\(names)准备好、门能开。"
    }
}

// MARK: - 导出（健哥令⑧：单客户/全量导出成文件；第七轮②双语）

enum Exporter {
    /// 生成导出文本（单客户带宠物+预约；全量=全部）。语言跟随 AppLang（上架英文版=英文导出）
    static func makeText(data: Store.Data, ownerFilter: UUID? = nil) -> String {
        let en = AppLang.current == .en
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        let tf2 = DateFormatter()   // 健哥11-20令⑤：三闹钟导出用（只要时分）
        tf2.dateFormat = "HH:mm"
        df.locale = Locale(identifier: en ? "en_US" : "zh_CN")
        var lines: [String] = []
        let owners: [Owner]
        if let filter = ownerFilter {
            owners = data.owners.filter { $0.id == filter }
        } else {
            owners = data.owners
        }

        lines.append(en ? "GroomerBook Export · \(df.string(from: Date()))" : "宠物美容台账 导出 · \(df.string(from: Date()))")
        lines.append(String(repeating: "=", count: 40))
        for owner in owners {
            lines.append("")
            lines.append(en ? "[Client] \(owner.name)" : "【客户】\(owner.name)")
            if !owner.phone.isEmpty { lines.append(en ? "Phone: \(owner.phone)" : "电话：\(owner.phone)") }
            if !owner.email.isEmpty { lines.append(en ? "Email: \(owner.email)" : "邮箱：\(owner.email)") }
            if !owner.address.isEmpty { lines.append(en ? "Address: \(owner.address)" : "地址：\(owner.address)") }
            if !owner.familyMembers.isEmpty { lines.append(en ? "Family: \(owner.familyMembers)" : "家人：\(owner.familyMembers)") }
            if !owner.notes.isEmpty { lines.append(en ? "Notes: \(owner.notes)" : "备注：\(owner.notes)") }
            let pets = data.pets.filter { $0.ownerId == owner.id }
            if !pets.isEmpty {
                lines.append(en ? "-- Pets (\(pets.count)) --" : "-- 宠物（\(pets.count)）--")
                for p in pets {
                    let biteWords = en ? ["safe", "care", "bites"] : ["安全", "谨慎", "咬人"]
                    var l = "\(p.type.emoji) \(p.name)（\(p.type.display)·\(p.breed)·\(p.status.display)）"
                    if p.biteLevel > 0 { l += en ? " bite risk: \(biteWords[p.biteLevel])" : " 咬人风险:\(biteWords[p.biteLevel])" }
                    lines.append(l)
                    if !p.groomRecipe.isEmpty { lines.append(en ? "  Recipe: \(p.groomRecipe)" : "  配方：\(p.groomRecipe)") }
                    if !p.specialTools.isEmpty { lines.append(en ? "  Special tools: \(p.specialTools)" : "  特殊工具：\(p.specialTools)") }
                    if !p.favoriteFood.isEmpty { lines.append(en ? "  Loves to eat: \(p.favoriteFood)" : "  爱吃：\(p.favoriteFood)") }
                    if !p.favoritePetting.isEmpty { lines.append(en ? "  Loves petting: \(p.favoritePetting)" : "  爱摸：\(p.favoritePetting)") }
                    if !p.temperament.isEmpty { lines.append(en ? "  Temperament: \(p.temperament)" : "  脾气：\(p.temperament)") }
                }
            }
            let appts = data.appointments.filter { $0.ownerId == owner.id }.sorted { $0.date > $1.date }
            if !appts.isEmpty {
                lines.append(en ? "-- Visit History (\(appts.count)) --" : "-- 上门记录（\(appts.count)）--")
                for a in appts {
                    let petNames = a.petIds.compactMap { id in data.pets.first { $0.id == id }?.name }.joined(separator: en ? " & " : "和")
                    var l = "  \(df.string(from: a.date)) \(petNames) \(a.status.display) \(a.groomMinutes)\(en ? " min" : "分钟")"
                    if !a.remindMinutesList.isEmpty {
                        l += en ? " · \(a.remindMinutesList.count) reminder(s)" : " · 闹钟\(a.remindMinutesList.count)个"
                    }
                    // 健哥11-20令⑤：导出文本带三闹钟（有则显示）
                    var alarmBits: [String] = []
                    if let p = a.prepAlarm { alarmBits.append((en ? "prep " : "准备 ") + tf2.string(from: p)) }
                    if let d = a.departAlarm { alarmBits.append((en ? "depart " : "出发 ") + tf2.string(from: d)) }
                    if let e = a.endAlarm { alarmBits.append((en ? "end " : "结束 ") + tf2.string(from: e)) }
                    if !alarmBits.isEmpty {
                        l += en ? " · Alarms: " + alarmBits.joined(separator: ", ") : " · 闹钟：" + alarmBits.joined(separator: "，")
                    }
                    if !a.note.isEmpty { l += en ? " · Note: \(a.note)" : " · 备注：\(a.note)" }
                    lines.append(l)
                }
            }
        }
        if ownerFilter == nil {
            lines.append("")
            lines.append(String(repeating: "=", count: 40))
            lines.append(en ? "Total: \(data.owners.count) clients · \(data.pets.count) pets · \(data.appointments.count) visits"
                            : "合计：客户\(data.owners.count) · 宠物\(data.pets.count) · 上门\(data.appointments.count)次")
        }
        return lines.joined(separator: "\n")
    }
}
