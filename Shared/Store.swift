import Foundation

// MARK: - 数据模型（施工单：P1配方/P2咬人风险/P3主人联系/P4 no-show/P6疫苗/P7六周循环）

struct Owner: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String            // 主人姓名
    var phone: String           // 联系电话（健哥令①）
    var email: String           // 邮箱（健哥令①）
    var notes: String           // 性格/偏好/禁忌（P3："cat person, hates surprises" / "gate code 1234"）
    var noShowCount: Int        // 主人维度放鸽子合计（P4）

    init(id: UUID = UUID(), name: String, phone: String = "", email: String = "", notes: String = "", noShowCount: Int = 0) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.notes = notes
        self.noShowCount = noShowCount
    }
}

struct Dog: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var breed: String
    var weightKg: Double            // 决定默认时长档
    var ownerId: UUID
    var temperament: String         // 脾气自由文本（P2）
    var biteLevel: Int              // 0=绿安全 1=黄谨慎 2=红危险（P2）
    var groomRecipe: String         // 美容配方：刀头/洗毛精/造型（P1）
    var vaccineExpiry: Date?        // 疫苗到期日（P6，nil=未记）
    var noShowCount: Int            // 该狗维度放鸽子（P4）

    init(id: UUID = UUID(), name: String, breed: String = "", weightKg: Double = 10, ownerId: UUID,
         temperament: String = "", biteLevel: Int = 0, groomRecipe: String = "", vaccineExpiry: Date? = nil, noShowCount: Int = 0) {
        self.id = id
        self.name = name
        self.breed = breed
        self.weightKg = weightKg
        self.ownerId = ownerId
        self.temperament = temperament
        self.biteLevel = biteLevel
        self.groomRecipe = groomRecipe
        self.vaccineExpiry = vaccineExpiry
        self.noShowCount = noShowCount
    }

    /// 默认美容时长（分钟）——按体重档（移动美容行业口径：小型1h/中型1.5h/大型2h+）
    var defaultMinutes: Int {
        switch weightKg {
        case ..<8: return 60
        case ..<20: return 90
        case ..<35: return 120
        default: return 150
        }
    }
}

struct Appointment: Codable, Identifiable, Equatable {
    let id: UUID
    var dogId: UUID
    var date: Date
    var groomMinutes: Int       // 美容时长
    var driveBufferMinutes: Int // 车程缓冲（P1衍生：自设缓冲值，不碰导航）
    var status: Status          // scheduled / done / noshow
    var note: String

    enum Status: String, Codable { case scheduled, done, noshow }

    init(id: UUID = UUID(), dogId: UUID, date: Date, groomMinutes: Int, driveBufferMinutes: Int = 15, status: Status = .scheduled, note: String = "") {
        self.id = id
        self.dogId = dogId
        self.date = date
        self.groomMinutes = groomMinutes
        self.driveBufferMinutes = driveBufferMinutes
        self.status = status
        self.note = note
    }

    /// 建议下次预约 = 完成日 +42 天（P7 六周循环）
    static let reorderDays = 42
}

// MARK: - 存储（UserDefaults + Codable，全本地零账号——隐私卖点）

enum Store {
    static let key = "groomerbook.data.v1"

    struct Data: Codable {
        var owners: [Owner] = []
        var dogs: [Dog] = []
        var appointments: [Appointment] = []
    }

    static func load() -> Data {
        guard let raw = UserDefaults.standard.data(forKey: key),
              let d = try? JSONDecoder().decode(Data.self, from: raw) else { return Data() }
        return d
    }

    static func save(_ d: Data) {
        if let raw = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}

// MARK: - 快捷短信模板（P5：on-my-way 四要素——身份/ETA/狗名/准备事项）——中文版

enum MessageTemplate {
    /// 生成 on-my-way 短信文本（复制给用户自己粘贴到微信/短信）
    static func onMyWay(owner: Owner, dog: Dog, minutes: Int) -> String {
        "\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \(minutes) 分钟后到，请把\(dog.name)准备好、门能开。"
    }
}
