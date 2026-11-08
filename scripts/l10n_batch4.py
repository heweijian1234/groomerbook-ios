# -*- coding: utf-8 -*-
"""第四批（最后残留14处）L() 化"""
import io

pairs = {
 'GroomerBook/GroomerBookApp.swift': [
  ('Text("📍 今天上门")', 'Text(L("📍 Today\'s visit", "📍 今天上门"))'),
  ('.navigationTitle("我的")', '.navigationTitle(L("Me", "我的"))'),
 ],
 'GroomerBook/Editors.swift': [
  ('Label("选照片", systemImage: "photo.badge.plus")', 'Label(L("Choose Photo", "选照片"), systemImage: "photo.badge.plus")'),
  ('Section("美容配方")', 'Section(L("Grooming Recipe", "美容配方"))'),
  ('Section("特殊工具携带")', 'Section(L("Special Tools to Bring", "特殊工具携带"))'),
  ('Label("有 \\(owner.noShowCount + ownerPets.reduce(0) { $0 + $1.noShowCount }) 次没成功记录——建议收押金",', None),  # 手动
  ('Text("45 分钟")', 'Text(L("45 min", "45 分钟"))'),
  ('Text("60 分钟")', 'Text(L("60 min", "60 分钟"))'),
  ('Text("90 分钟")', 'Text(L("90 min", "90 分钟"))'),
  ('Text("120 分钟")', 'Text(L("120 min", "120 分钟"))'),
  ('Text("150 分钟")', 'Text(L("150 min", "150 分钟"))'),
  ('Text("180 分钟")', 'Text(L("180 min", "180 分钟"))'),
  ('Stepper("车程缓冲 \\(buffer) 分钟", value: $buffer, in: 0...60, step: 5)', 'Stepper(L("Drive buffer \\(buffer) min", "车程缓冲 \\(buffer) 分钟"), value: $buffer, in: 0...60, step: 5)'),
  ('Label("全部清除", systemImage: "trash")', 'Label(L("Clear all", "全部清除"), systemImage: "trash")'),
 ],
}

for f, repl in pairs.items():
    src = io.open(f, encoding='utf-8').read()
    for old, new in repl:
        if new is None:
            continue
        if old in src:
            src = src.replace(old, new)
    # 手动处理 noShowWarn 复合串（正则）
    src = src.replace(
        'Label("有 \\(owner.noShowCount + ownerPets.reduce(0) { $0 + $1.noShowCount }) 次没成功记录——建议收押金", systemImage: "exclamationmark.triangle.fill")',
        'Label(L10n.noShowWarn(owner.noShowCount + ownerPets.reduce(0) { $0 + $1.noShowCount }), systemImage: "exclamationmark.triangle.fill")')
    io.open(f, 'w', encoding='utf-8').write(src)
print('batch4 done')
