import SwiftUI

// MARK: - 狗编辑器（新建/编辑）——配方P1/咬人风险P2/疫苗P6/体重档

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
                Section("Dog") {
                    TextField("Name", text: $name)
                    TextField("Breed", text: $breed)
                    HStack {
                        Text("Weight")
                        Slider(value: $weight, in: 1...70, step: 1)
                        Text("\(Int(weight)) kg").monospacedDigit().frame(width: 56)
                    }
                    // 体重档对应的默认时长提示（施工单）
                    Text("Default groom: \(defaultMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Owner") {
                    if data.owners.isEmpty {
                        Text("Add an owner first (Owners tab).")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("Owner", selection: $ownerId) {
                            ForEach(data.owners) { o in
                                Text(o.name).tag(Optional(o.id))
                            }
                        }
                    }
                }
                Section("Behavior") {
                    Picker("Bite risk", selection: $biteLevel) {
                        Text("Safe").tag(0)
                        Text("Care").tag(1)
                        Text("BITE RISK").tag(2)
                    }
                    .pickerStyle(.segmented)
                    TextField("Temperament notes (anxious, fine with cats…)", text: $temperament, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Grooming recipe") {
                    TextField("Blade / shampoo / style notes", text: $groomRecipe, axis: .vertical)
                        .lineLimit(4...8)
                }
                Section("Vaccine") {
                    Toggle("Track vaccine expiry", isOn: $hasVaccine)
                    if hasVaccine {
                        DatePicker("Expires", selection: $vaccineExpiry, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Dog" : "Edit Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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

// MARK: - 主人编辑器（联系方式+邮箱 健哥令① / 偏好禁忌 P3）

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
                Section("Owner") {
                    TextField("Name", text: $name)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                Section("Preferences & notes") {
                    TextField("Personality, preferences, gate code, do-nots…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existing == nil ? "New Owner" : "Edit Owner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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

// MARK: - 预约编辑器（建预约时 no-show 警示 P4 + 默认时长按体重档）

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
        return total > 0 ? "⚠️ \(total) no-show\(total > 1 ? "s" : "") on record — consider a deposit" : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if data.dogs.isEmpty {
                        Text("Add a dog first (Dogs tab).")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    } else {
                        Picker("Dog", selection: $dogId) {
                            ForEach(data.dogs) { d in
                                Text(d.name).tag(Optional(d.id))
                            }
                        }
                        .onChange(of: dogId) { _, nv in
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
                Section("When") {
                    DatePicker("Date & time", selection: $date)
                    Stepper("\(minutes) min groom", value: $minutes, in: 15...300, step: 15)
                    Stepper("\(buffer) min drive buffer", value: $buffer, in: 0...60, step: 5)
                }
                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
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
