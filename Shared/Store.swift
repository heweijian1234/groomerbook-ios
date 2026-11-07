import Foundation

// MARK: - 数据模型 v2（健哥 11-07 真机测试修改意见：
// ②以人为主：主人是第一实体，狗挂主人下，主人可加家人；③美容服务市场可选/自填；
// ⑥主人带地址；⑦宠物类型不只有狗；⑧特殊工具携带清单）

enum PetType: String, Codable, CaseIterable {
    case dog = "狗"
    case cat = "猫"
    case rabbit = "兔"
    case bird = "鸟"
    case other = "其他"

    var emoji: String {
        switch self { case .dog: return "🐕"; case .cat: return "🐈"; case .rabbit: return "🐇"; case .bird: return "🐦"; case .other: return "🐾" }
    }
}

struct Owner: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String            // 主人姓名
    var phone: String           // 联系电话（点击自动拨号）
    var email: String           // 邮箱
    var address: String         // 上门地址（健哥令⑥：首页直接显示+导航）
    var familyMembers: String   // 家人（健哥令②：家里谁对接/谁管宠物）
    var notes: String           // 性格/偏好/禁忌
    var noShowCount: Int        // 放鸽子（改约没成功）合计

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
    var type: PetType           // 宠物类型（健哥令⑦：不止狗——猫/兔/鸟/其他/自填）
    var breed: String
    var weightKg: Double
    var ownerId: UUID
    var temperament: String     // 脾气
    var biteLevel: Int          // 0=安全 1=谨慎 2=咬人
    var groomRecipe: String     // 美容配方（造型/刀头/洗毛精）
    var specialTools: String    // 特殊工具携带清单（健哥令⑧：避免忘带）
    var vaccineExpiry: Date?
    var noShowCount: Int

    init(id: UUID = UUID(), name: String, type: PetType = .dog, breed: String = "", weightKg: Double = 10,
         ownerId: UUID, temperament: String = "", biteLevel: Int = 0, groomRecipe: String = "",
         specialTools: String = "", vaccineExpiry: Date? = nil, noShowCount: Int = 0) {
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
        self.vaccineExpiry = vaccineExpiry
        self.noShowCount = noShowCount
    }

    var defaultMinutes: Int {
        // 猫通常比狗快一些；大体型时间长
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
    var petId: UUID
    var date: Date
    var groomMinutes: Int
    var driveBufferMinutes: Int // 车程缓冲
    var status: Status
    var note: String

    enum Status: String, Codable {
        case scheduled = "已约"
        case done = "已完成"
        case noshow = "没成功"      // 健哥令④：上门服务放鸽子=没成功（不是"没来"——是美容师出门了客户没成单）
        case canceled = "已取消"
    }

    init(id: UUID = UUID(), petId: UUID, date: Date, groomMinutes: Int, driveBufferMinutes: Int = 15,
         status: Status = .scheduled, note: String = "") {
        self.id = id
        self.petId = petId
        self.date = date
        self.groomMinutes = groomMinutes
        self.driveBufferMinutes = driveBufferMinutes
        self.status = status
        self.note = note
    }

    static let reorderDays = 42
}

// MARK: - 美容服务市场（健哥令①：可选或自填——用于统计哪个渠道的单多）

struct ServiceMarket: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String            // 小区名/渠道名（自填，如"幸福花园""美团""老客转介绍"）
    var note: String

    init(id: UUID = UUID(), name: String, note: String = "") {
        self.id = id
        self.name = name
        self.note = note
    }
}

// MARK: - 存储 v2（v1 数据自动迁移：狗→宠物，主人加新字段默认值）

enum Store {
    static let key = "groomerbook.data.v2"

    struct Data: Codable {
        var owners: [Owner] = []
        var pets: [Pet] = []
        var appointments: [Appointment] = []
        var markets: [ServiceMarket] = []       // 美容服务市场（自填）
    }

    static func load() -> Data {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let d = try? JSONDecoder().decode(Data.self, from: raw) else {
            return migrateV1() ?? Data()
        }
        return d
    }

    /// v1（dogs 命名）→ v2（pets）迁移
    private static func migrateV1() -> Data? {
        guard let raw = UserDefaults.standard.data(forKey: "groomerbook.data.v1"),
              let old = try? JSONDecoder().decode(OldV1.self, from: raw) else { return nil }
        var d = Data()
        d.owners = old.owners
        d.pets = old.dogs.map { oldDog in
            Pet(id: oldDog.id, name: oldDog.name, type: .dog, breed: oldDog.breed, weightKg: oldDog.weightKg,
                ownerId: oldDog.ownerId, temperament: oldDog.temperament, biteLevel: oldDog.biteLevel,
                groomRecipe: oldDog.groomRecipe, specialTools: "", vaccineExpiry: oldDog.vaccineExpiry,
                noShowCount: oldDog.noShowCount)
        }
        d.appointments = old.appointments
        if let raw2 = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(raw2, forKey: key)
        }
        return d
    }

    private struct OldV1: Codable {
        var owners: [Owner]
        var dogs: [OldDog]
        var appointments: [Appointment]
    }

    private struct OldDog: Codable {
        let id: UUID; var name: String; var breed: String; var weightKg: Double; var ownerId: UUID
        var temperament: String; var biteLevel: Int; var groomRecipe: String
        var vaccineExpiry: Date?; var noShowCount: Int
    }

    static func save(_ d: Data) {
        if let raw = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}

// MARK: - 快捷短信模板（中文版；④措辞对齐：上门服务）

enum MessageTemplate {
    static func onMyWay(owner: Owner, pet: Pet, minutes: Int) -> String {
        "\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \(minutes) 分钟后到，请把\(pet.name)准备好、门能开。"
    }
}
