# 任务书：GroomerBook 上架全套（②截图→③隐私页→④填料→⑤六必填→就绪态）· 2026-11-07

- 派工窗：主窗 · 执行窗：flash
- 项目：GroomerBook（目录 `SaaS项目\groomerbook-ios`，仓 github-heweijian/groomerbook-ios，CI 已绿 build 就绪）
- 前置状态：
  - ✅ 代码完成+CI 全绿（push 轮 success，但 **TestFlight 上传轮还没 dispatch**——见任务第0步）
  - ✅ 施工单（功能与卖点来源）：`SaaS项目\research\宠物美容师App-痛点清单与施工单-2026-11-07.md`
  - ⚠️ **ASC App 档案=健哥正在网页建**（APP_ID 未定；且健哥第一次建错了 bundleId，正确= `com.zeronelabs.groomerbook`）
- 输入文件（必读，按序）：
  1. `C:\Users\Administrator\.claude\skills\ios-appstore-launch\SKILL.md`（全篇，含地雷表+附录B2）
  2. `C:\Users\Administrator\.claude\skills\ios-appstore-launch\派工任务书模板.md`（交接格式）
  3. 施工单（上面路径，文案取材用）
  4. 本文件

## 要做的（按序）

### 第0步：等 ASC 档案
用 `hypermobility-ios\store\asc_备注与重提.py` 的 JWT 造法查 `GET /v1/apps?limit=20`：
- 找到 name=`GroomerBook` 且 bundleId=`com.zeronelabs.groomerbook`（🔴不带 .widget 后缀）的记录 → 记下 APP_ID 进下一步
- 只有带 .widget 的错误档案 → **停笔**，在交接书写"等健哥重建成正确 bundleId"，不做任何后续
- 建议轮询间隔 120s，最多等 40 分钟；超时照常交棒停笔

### 第1步：CI 上传 TestFlight（SKILL 附录A）
```
dispatch 上传轮：gh workflow run 'iOS Release (TestFlight)' -R heweijian1234/groomerbook-ios --ref main -f upload_testflight=true
（gh 需 export HTTPS_PROXY='socks5://127.0.0.1:1080'）
🔴push 绿≠完成：必须 dispatch 且等上传轮绿 → builds 查到 VALID
```

### 第2步：②截图（SKILL ④段前的②段）
- 母版：`grindsnore-ios\store\make_screenshots.ps1` + 参考成品 `countdown-days-ios\store\make_screenshots.ps1`
- 三张 1290×2796 落 `groomerbook-ios\store\`，改色/文案自定（橙棕暖色系适合宠物主题）
- 文案素材（施工单 P1-P7）：shot1 主张"Remember every dog, win every rebook"；shot2 狗档案卡（配方/咬人风险红黄绿/疫苗到期）；shot3 主人联系+on-my-way 快捷短信
- ⚠️文案全英文；🔴截图不得出现"diagnose/treat/medical"字样（健康措辞纪律）

### 第3步：③隐私页
- 母版 `grindsnore-ios\store\grindsnore-privacy.html` → `groomerbook-ios\store\groomerbook-privacy.html`
- 要点：不收集任何数据/无账号/无网络/录音权限都没有（这 App 连麦克风都不用）
- scp 部署 VPS（`scp -P 6181 root@192.220.45.139:/opt/postwriter/seo_pages/groomerbook-privacy.html`）→ curl 必须 200

### 第4步：④七语填料（核心段）
- 母版：**`countdown-days-ios\store\asc_填料.py`（最新最全版，带 assert+截图集修复——就用这份）**
- 复制到 `groomerbook-ios\store\` 改：APP_ID（第0步拿到的）/VER=1.0/STORE/PRIVACY_URL/APP_NAME=GroomerBook/LOCALES 七语文案
- 文案方向（从施工单取材，填空不是作文）：
  - en subtitle（≤30）："Dog & client book for groomers"
  - en keywords（≤100）：dog grooming, groomer, pet business, client records, dog tracker, appointment…
  - 主张一句："Remember every dog's recipe. Flag the biters. Never miss a rebook."
  - 功能列表对齐 P1-P7；隐私段"No account. No network. Nothing leaves this phone."
  - 🔴全 locale 禁 diagnose/treat/medical/veterinary advice 类词（健康类雷区，工具定位）
- 字符预算 assert 必须在；跑完 API 回读抽查

### 第5步：⑤六必填（SKILL ⑤段照做）
- API 能做的全做：build 关联（单数 relationships/build）/主类别 LIFESTYLE 或 UTILITIES（自选一个，交接书说明理由）/年龄分级（双 override 都不发）
- 网页项（版权/隐私标签/定价/审核联系人/手动发布）：**列清单进交接书**，主窗汇总后提醒健哥点——**flash 不要碰 ASC 网页**
- 版本发布方式注意：建版本时 releaseType=MANUAL 已定，如查到非 MANUAL 要在交接书标红

### 第6步：交棒
- 产物全落 `groomerbook-ios\store\`
- 写 `groomerbook-ios\store\交接-2026-11-07-GroomerBook上架全套.md`（模板五件套）
- 就绪态总表：六段状态+网页人工项清单+建议提审语（备注模板：Simple local business tool for mobile dog groomers. No account, no network, no data collection. Demo: add owner→add dog→book appointment→see no-show warning and on-my-way text.）

## 🔴禁做
1. **不提交审核**（提审=健哥）
2. **不碰 ASC 网页**（网页项列清单交回主窗）
3. 不改 SKILL.md（新坑写交接书，主窗回填）
4. 不动 countdown/grindsnore/hypermobility 三目录
5. build 无 VALID 时不空等：先按附录A dispatch 上传轮，上传轮失败 rerun 一次再停笔
