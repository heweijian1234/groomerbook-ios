# -*- coding: utf-8 -*-
"""第五批：通知文案/短信模板/导出文本/剩余Picker标签 L() 化（上架英文版收尾）"""
import io

# === GroomerBookApp.swift：通知 hoursText + 文案 + 预约卡标签 ===
f = 'GroomerBook/GroomerBookApp.swift'
src = io.open(f, encoding='utf-8').read()
repl = [
  # 通知时长文案（schedule 内）
  ('        let hoursText = { (mins: Int) -> String in\n            mins >= 60 ? "提前 \\(mins / 60) 小时" : "提前 \\(mins) 分钟"\n        }',
   '        let hoursText = { (mins: Int) -> String in\n            mins >= 60 ? L("\\(mins / 60)h before", "提前 \\(mins / 60) 小时") : L("\\(mins) min before", "提前 \\(mins) 分钟")\n        }'),
  ('content.title = "上门提醒（\\(hoursText(mins))）"',
   'content.title = L("Visit reminder (\\(hoursText(mins)))", "上门提醒（\\(hoursText(mins))）")'),
  ('content.body = "\\(hoursText(mins))出发去 \\(ownerName) 家（\\(petNames)）。\\(mins >= 120 ? "记得带齐工具。" : "")"',
      ('content.body = "\(hoursText(mins))出发去 \(ownerName) 家（\(petNames)）。\(mins >= 120 ? "记得带齐工具。" : "")"',
    'content.body = AppLang.current == .en
                ? "\(hoursText(mins)) — heading to " + ownerName + "'s place (" + petNames + ")." + (mins >= 120 ? " Pack your tools." : "")
                : "\(hoursText(mins))出发去 \(ownerName) 家（\(petNames)）。\(mins >= 120 ? "记得带齐工具。" : "")"'),
  ('"未知客户"', 'L("Unknown client", "未知客户")'),
  ('let labels = appt.remindMinutesList.sorted().map { mins in\n                    mins >= 60 ? "提前\\(mins / 60)小时" : "提前\\(mins)分钟"\n                }.joined(separator: "、")',
   'let labels = appt.remindMinutesList.sorted().map { mins in\n                    mins >= 60 ? L("\\(mins / 60)h before", "提前\\(mins / 60)小时") : L("\\(mins) min before", "提前\\(mins)分钟")\n                }.joined(separator: AppLang.current == .en ? ", " : "、")'),
  ('Label(labels + "提醒", systemImage: "bell.fill")',
   'Label(labels + L(" reminder", "提醒"), systemImage: "bell.fill")'),
  ('Text(pets.map { "\\($0.type.emoji)\\($0.name)" }.joined(separator: " ") + " · \\(appt.groomMinutes)分钟 · 缓冲\\(appt.driveBufferMinutes)分钟")',
   'Text(pets.map { "\\($0.type.emoji)\\($0.name)" }.joined(separator: " ") + " · \\(appt.groomMinutes) " + L("min", "分钟") + " · " + L("\\(appt.driveBufferMinutes) min buffer", "缓冲\\(appt.driveBufferMinutes)分钟"))'),
  # 今日上门卡
  ('Text("\\(petNames) · \\(appt.groomMinutes)分钟").font(.caption).foregroundColor(.secondary)',
   'Text("\\(petNames) · \\(appt.groomMinutes) " + L("min", "分钟")).font(.caption).foregroundColor(.secondary)'),
  # 客户详情小标
  ('Text("\\(owner.noShowCount) 次没成功")',
   'Text("\\(owner.noShowCount) " + L("no-shows", "次没成功"))'),
  # 状态标签（PetDetailView）
  ('Text(current.status.display)', None),
  ('Label("状态：\\(current.status.display)"', None),
]
miss = []
for old, new in repl:
    if new is None:
        continue
    if old in src:
        src = src.replace(old, new)
    else:
        miss.append(old[:50])
io.open(f, 'w', encoding='utf-8').write(src)
for m in miss:
    print('MISS A:', m)

# === Editors.swift：剩余 Picker 标签/反馈主题 ===
f2 = 'GroomerBook/Editors.swift'
src = io.open(f2, encoding='utf-8').read()
repl2 = [
  ('Picker("类型", selection: $type)', 'Picker(L("Type", "类型"), selection: $type)'),
  ('Picker("客户", selection: $ownerId)', 'Picker(L("Client", "客户"), selection: $ownerId)'),
  ('Picker("咬人风险", selection: $biteLevel)', 'Picker(L("Bite risk", "咬人风险"), selection: $biteLevel)'),
  ('Picker("当前状态", selection: $status)', 'Picker(L("Current status", "当前状态"), selection: $status)'),
  ('Picker("美容时长", selection: $minutes)', 'Picker(L("Groom duration", "美容时长"), selection: $minutes)'),
  ('Picker("闹钟 \\(idx + 1)", selection: $remindSelections[idx])', 'Picker(L("Reminder \\(idx + 1)", "闹钟 \\(idx + 1)"), selection: $remindSelections[idx])'),
  ('let subject = "宠物美容台账-用户反馈"',
   'let subject = L("GroomerBook - user feedback", "宠物美容台账-用户反馈")'),
  ('Stepper("车程缓冲 \\(buffer) 分钟", value: $buffer, in: 0...60, step: 5)',
   'Stepper(L("Drive buffer \\(buffer) min", "车程缓冲 \\(buffer) 分钟"), value: $buffer, in: 0...60, step: 5)'),
  ('let names = pets.map { $0.name }.joined(separator: "和")',
   None),
]
miss2 = []
for old, new in repl2:
    if new is None:
        continue
    if old in src:
        src = src.replace(old, new)
    else:
        miss2.append(old[:44])
# PetType Picker（两处同款）
src = src.replace('Text("\\(t.emoji) \\(t.display)").tag(t)', 'Text("\\(t.emoji) \\(t.display)").tag(t)')
io.open(f2, 'w', encoding='utf-8').write(src)
for m in miss2:
    print('MISS B:', m)

# === Store.swift：短信模板+导出文本双语 ===
f3 = 'Shared/Store.swift'
src = io.open(f3, encoding='utf-8').read()
repl3 = [
  ('enum MessageTemplate {\n    static func onMyWay(owner: Owner, pets: [Pet], minutes: Int) -> String {\n        let names = pets.map { $0.name }.joined(separator: "和")\n        return "\\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \\(minutes) 分钟后到，请把\\(names)准备好、门能开。"\n    }\n}',
   '''enum MessageTemplate {
    static func onMyWay(owner: Owner, pets: [Pet], minutes: Int) -> String {
        let sep = AppLang.current == .en ? " & " : "和"
        let names = pets.map { $0.name }.joined(separator: sep)
        if AppLang.current == .en {
            return "Hi \\(owner.name), this is your groomer — on my way now for \\(names), about \\(minutes) min out. Please have them ready and the gate accessible."
        }
        return "\\(owner.name)您好，我是您的宠物美容师——现在正在前往您家的路上，预计 \\(minutes) 分钟后到，请把\\(names)准备好、门能开。"
    }
}'''),
]
miss3 = []
for old, new in repl3:
    if old in src:
        src = src.replace(old, new)
    else:
        miss3.append(old[:60])
io.open(f3, 'w', encoding='utf-8').write(src)
for m in miss3:
    print('MISS C:', m)
print('batch5 done')
