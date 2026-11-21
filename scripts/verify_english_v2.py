# G 上架前裸中文扫描 v2（自查工具）
# 规则：L("en","zh") 的 zh 参数合法（双语机制）；注释合法；枚举 rawValue 合法（Codable 存储值）
# 剩下的用户可见裸中文 = 上架英文版违规，报出来人工判
import re
import glob
import sys

files = glob.glob('GroomerBook/*.swift') + glob.glob('Shared/*.swift')
l_params = set()
all_cn = []
CN = u'[一-鿿]'

for f in files:
    src = open(f, encoding='utf-8').read()
    # 1. 收集所有 L(...) 的字符串参数（含跨行）
    for m in re.finditer(u'L\\(\\s*"((?:[^"\\\\]|\\\\.)*)"\\s*(?:,\\s*"((?:[^"\\\\]|\\\\.)*)"\\s*)?\\)', src, re.S):
        l_params.add(m.group(1))
        if m.group(2):
            l_params.add(m.group(2))
    # 2. 扫含中文的字符串字面量（单行内）
    pat = u'"([^"\\n]*' + CN + u'[^"\\n]*)"'
    for m in re.finditer(pat, src):
        s = m.group(1)
        if s in l_params:
            continue
        line_no = src[:m.start()].count('\n') + 1
        line = src.split('\n')[line_no - 1].strip()
        if line.startswith('//') or line.startswith('*'):
            continue
        if ('= "' + s + '"') in line:
            continue  # 枚举 rawValue
        # 排除跨行 L( 调用的参数（该字符串往前 200 字符有未闭合的 L(）
        before = src[max(0, m.start() - 200):m.start()]
        open_l = before.count('L(') - before.count(')')
        # 上面计数不可靠，改用位置法：往前找最近的 L( 与最近的 ")"——L(更近则疑似参数
        last_l = before.rfind('L(')
        last_close = before.rfind(')')
        if last_l > last_close:
            continue
        all_cn.append((f, line_no, s[:50]))

seen = set()
for f, ln, s in all_cn:
    k = (f, s)
    if k in seen:
        continue
    seen.add(k)
    print(u'%s:%d: %s' % (f.replace('\\', '/').split('/')[-1], ln, s))
print(u'— 共 %d 处待人工判' % len(seen))
