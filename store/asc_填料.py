# -*- coding: utf-8 -*-
"""GroomerBook ASC 上架填料（照 countdown 最新母版；前置：build 20 VALID 已在 ASC）
七语满填：en/ja/de/fr/es + zh-Hans/zh-Hant（健哥规矩：新 App 简繁从 v1 带）
"""
import time, json, base64, sys, hashlib, urllib.request
import os

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

KEY_ID = "L3UHT69Y77"
ISSUER_ID = "98812827-46d0-4c8f-9b91-35d4f783e6df"
P8_PATH = r"E:\AI-Projects\个人成长\50-Skills\密钥\苹果\AuthKey_L3UHT69Y77.p8"
APP_ID = "6831985044"   # GroomerBook
VER = "1.0"
STORE = r"E:\AI-Projects\个人成长\10-项目\SaaS项目\groomerbook-ios\store"
PRIVACY_URL = "https://postwriter.cn/seo/groomerbook-privacy.html"
APP_NAME = "GroomerBook"

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()

from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes

key = load_pem_private_key(open(P8_PATH, "rb").read(), password=None)
h = b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
p = b64url(json.dumps({"iss": ISSUER_ID, "iat": int(time.time()), "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}).encode())
sig = key.sign(f"{h}.{p}".encode(), ec.ECDSA(hashes.SHA256()))
def raw(s):
    i = 2
    if s[1] & 0x80: i += s[1] & 0x7f
    def ri():
        nonlocal i
        i += 1; ln = s[i]; i += 1
        if ln & 0x80:
            n = ln & 0x7f; ln = 0
            for _ in range(n): ln = (ln << 8) | s[i]; i += 1
        v = int.from_bytes(s[i:i+ln], "big"); i += ln; return v.to_bytes(32, "big")
    return ri() + ri()
jwt = f"{h}.{p}.{b64url(raw(sig))}"

def asc(url, data=None, method=None):
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers={"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"}, method=method or ("POST" if data else "GET"))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")
        except Exception as ex:
            if attempt == 3: return -1, {"err": str(ex)}
            time.sleep(3)

EN_DESC = """The grooming book built for mobile dog groomers.

Remember every dog. Win every rebook.

GroomerBook keeps your clients and their pets organized — so the next visit starts from the last recipe, not from memory.

▸ DOG PROFILES
Grooming recipe (blade, shampoo, style) written once and reused. Bite-risk flags. Vaccine expiry tracking. Special tools to bring — never forget the large dryer again.

▸ CLIENT PROFILES
Phone, email, service address — tap to call, tap to navigate. Family contact notes. Preferences and do-nots. No-show counter with a deposit hint when a client has a history.

▸ APPOINTMENTS
Multi-pet visits. Drive-time buffer. Up to 3 reminders per appointment (1-10 hours before) so you leave on time.

▸ MONTHLY SUMMARY
Visits, revenue and mileage for the month — your bookkeeping starts here.

PRIVATE BY DESIGN
No account. No cloud. No ads. No analytics. No network access at all — your records never leave your device.

FREE AND SIMPLE
Unlimited clients, unlimited pets, all features free. Deleting the app removes everything instantly — because nothing was ever sent anywhere."""

LOCALES = {
    "en-US": {"subtitle": "Dog grooming client & pet book",
              "keywords": "dog grooming,groomer,mobile groomer,pet business,client records,appointment,dog tracker,salon",
              "description": EN_DESC},
    "ja": {"subtitle": "ドグルーマーの顧客台帳",
           "keywords": "ドッググルーミング,トリマー,顧客管理,ペット,予約,トリミング,記録,犬",
           "description": "移動式ドッググルーマーのためのトリミング台帳。\n\nすべての犬を覚え、リピートを逃さない。\n\nGroomerBook は顧客とペットの情報を整理——次回の訪問は記憶ではなく、前回のレシピから始められます。\n\n▸ 犬のプロファイル\n刀の番号・シャンプー・スタイルのレシピを一度書けば毎回使える。咬傷リスク表示。ワクチン期限管理。持参すべき特別な道具のリスト——大型ドライヤーの忘れ物はもうありません。\n\n▸ 顧客プロファイル\n電話・メール・住所——タップで発信、タップでナビゲーション。家族の連絡メモ。好みや注意事項。ドタキャン履歴からデポジットの提案まで。\n\n▸ 予約\n複数ペット対応。移動時間バッファ。予約ごとに最大3つのリマインダー（1〜10時間前）。\n\nプライバシー設計：アカウントなし・クラウドなし・広告なし。ネットワークアクセス自体がなく、記録は端末から出ません。\n\n無料でシンプル：顧客もペットも無制限、全機能無料。"},
    "de-DE": {"subtitle": "Kundenbuch für Hundepfleger",
           "keywords": "Hundepflege,Hundefrisör,mobiler Pfleger,Kundenbuch,Terminbuch,Tierpflege,Hundesalon",
           "description": "Das Pflegebuch für mobile Hundefrisöre.\n\nJeden Hund erkennen. Jede Wiederbuchung gewinnen.\n\nGroomerBook hält Kunden und ihre Hunde organisiert — der nächste Besuch startet mit dem letzten Rezept, nicht aus dem Gedächtnis.\n\n▸ HUNDEPROFILE\nPflegerezept (Klingenblatt, Shampoo, Stil) einmal notiert, bei jedem Besuch wiederverwendet. Beiß-Risiko-Markierung. Impf-Fristen. Spezialwerkzeug zum Mitbringen — den großen Fön vergisst du nie wieder.\n\n▸ KUNDENPROFILE\nTelefon, E-Mail, Serviceadresse — tippen zum Anrufen, tippen zur Navigation. Familien-Notizen. Präferenzen und Tabus. No-Show-Zähler mit Anzahlungshinweis.\n\n▸ TERMINE\nMehrere Hunde pro Besuch. Fahrzeit-Puffer. Bis zu 3 Erinnerungen pro Termin (1-10 Std. vorher).\n\nPRIVAT VON DESIGN: Kein Konto. Keine Cloud. Keine Werbung. Kein Netzwerkzugriff — deine Daten verlassen das Gerät nie.\n\nKOSTENLOS: Unbegrenzte Kunden und Hunde, alle Funktionen gratis."},
    "fr-FR": {"subtitle": "Carnet toiletteur canin",
           "keywords": "toilettage,chien,toiletteur,carnet client,rendez-vous,gestion client,salon canin",
           "description": "Le carnet de toilettage pour toiletteurs à domicile.\n\nRetenez chaque chien. Gagnez chaque re-réservation.\n\nGroomerBook organise vos clients et leurs chiens — la prochaine visite démarre avec la dernière recette, pas de mémoire.\n\n▸ FICHES CHIEN\nRecette de toilettage (lame, shampoing, style) écrite une fois, réutilisée à chaque visite. Signal de risque de morsure. Suivi des vaccins. Outils spéciaux à apporter — ne plus jamais oublier le grand séchoir.\n\n▸ FICHES CLIENT\nTéléphone, e-mail, adresse — touchez pour appeler, touchez pour naviguer. Notes famille. Préférences et interdits. Compteur de rendez-vous manqués avec suggestion d'acompte.\n\n▸ RENDEZ-VOUS\nVisites multi-chiens. Marge de trajet. Jusqu'à 3 rappels par rendez-vous (1 à 10 h avant).\n\nCONFIDENTIALITÉ PAR CONCEPTION : aucun compte, aucun cloud, aucune pub, aucun accès réseau — vos données ne quittent jamais votre appareil.\n\nGRATUIT : clients et chiens illimités, toutes les fonctions gratuites."},
    "es-ES": {"subtitle": "Libro peluquero canino",
           "keywords": "peluquería canina,perros,peluquero,libro clientes,citas,grooming,estética canina",
           "description": "El libro de aseo para peluqueros caninos a domicilio.\n\nRecuerda a cada perro. Gana cada repetición.\n\nGroomerBook organiza tus clientes y sus perros — la siguiente visita empieza con la última receta, no de memoria.\n\n▸ FICHAS DE PERRO\nReceta de aseo (navaja, champú, estilo) escrita una vez, reutilizada en cada visita. Aviso de riesgo de mordida. Control de vacunas. Herramientas especiales para llevar — nunca más olvides el secador grande.\n\n▸ FICHAS DE CLIENTE\nTeléfono, email, dirección — toca para llamar, toca para navegar. Notas de familia. Preferencias y prohibiciones. Contador de ausencias con sugerencia de depósito.\n\n▸ CITAS\nVisitas multi-perro. Margen de conducción. Hasta 3 recordatorios por cita (1-10 h antes).\n\nPRIVACIDAD POR DISEÑO: sin cuenta, sin nube, sin anuncios, sin acceso a red — tus datos nunca salen del dispositivo.\n\nGRATIS: clientes y perros ilimitados, todas las funciones gratis."},
    "zh-Hans": {"subtitle": "宠物美容师上门服务台账",
           "keywords": "宠物美容,美容师,上门服务,客户管理,宠物档案,预约管理,狗狗记录,美容预约,宠物店,客户台账",
           "description": "为上门宠物美容师打造的登记本。\n\n记住每一只狗，不漏每一次复购。\n\nGroomerBook 把客户和宠物信息整理得清清楚楚——下次上门从上次配方开始，不靠记忆。\n\n▸ 宠物档案\n美容配方（刀头/洗毛精/造型）写一次反复用。咬人风险标记。疫苗到期跟踪。特殊工具携带清单——大型吹水机再也不会忘带。\n\n▸ 客户档案\n电话、邮箱、上门地址——点击拨号、点击导航。家人对接备注。偏好与禁忌。放鸽子计数+押金提示。\n\n▸ 预约\n一单多宠物。车程缓冲。每单最多 3 个提醒（提前 1-10 小时），准时出门不迟到。\n\n隐私设计：无账号、无云端、无广告、无任何联网——数据永远不离开设备。\n\n免费简洁：客户宠物不限量，全功能免费。"},
    "zh-Hant": {"subtitle": "寵物美容師上門服務台賬",
           "keywords": "寵物美容,美容師,上門服務,客戶管理,寵物檔案,預約管理,狗狗記錄,美容預約,寵物店,客戶台賬",
           "description": "為上門寵物美容師打造的登記本。\n\n記住每一隻狗，不漏每一次複購。\n\nGroomerBook 把客戶和寵物資訊整理得清清楚楚——下次上門從上次配方開始，不靠記憶。\n\n▸ 寵物檔案\n美容配方（刀頭/洗毛精/造型）寫一次反復用。咬人風險標記。疫苗到期追蹤。特殊工具攜帶清單——大型吹水機再也不會忘帶。\n\n▸ 客戶檔案\n電話、郵箱、上門地址——點擊撥號、點擊導航。家人對接備註。偏好與禁忌。放鴿子計數+押金提示。\n\n▸ 預約\n一單多寵物。車程緩衝。每單最多 3 個提醒（提前 1-10 小時），準時出門不遲到。\n\n隱私設計：無帳號、無雲端、無廣告、無任何聯網——資料永遠不離開裝置。\n\n免費簡潔：客戶寵物不限量，全功能免費。"},
}

# 字符预算 assert（30/100 硬限——超限宁可截尾不硬塞）
for loc, info in LOCALES.items():
    assert len(info["subtitle"]) <= 30, f"{loc} subtitle 超限: {len(info['subtitle'])}"
    assert len(info["keywords"]) <= 100, f"{loc} keywords 超限: {len(info['keywords'])}"
    print(f"budget {loc}: subtitle={len(info['subtitle'])}/30 keywords={len(info['keywords'])}/100 OK")

# 1. 版本
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")
vers = r.get("data", [])
if not vers:
    print("[1] 无版本（异常）"); sys.exit(1)
ver_id = vers[0]["id"]
if vers[0]["attributes"].get("versionString") != VER:
    asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}",
        {"data": {"type": "appStoreVersions", "id": ver_id, "attributes": {"versionString": VER}}}, method="PATCH")
print(f"[1] 版本 {VER} id={ver_id} state={vers[0]['attributes'].get('appStoreState')}")

# 2. App 信息层（语言注册+名称+副标题+隐私URL）——subtitle在这层
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}?include=appInfos")
app_info_id = None
for inc in r.get("included", []):
    if inc["type"] == "appInfos":
        app_info_id = inc["id"]; break
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appInfos/{app_info_id}/appInfoLocalizations")
info_existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
for locale, info in LOCALES.items():
    attrs = {"name": APP_NAME, "subtitle": info["subtitle"], "privacyPolicyUrl": PRIVACY_URL}
    if locale in info_existing:
        st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appInfoLocalizations/{info_existing[locale]}",
                     {"data": {"type": "appInfoLocalizations", "id": info_existing[locale], "attributes": attrs}}, method="PATCH")
    else:
        st, rr = asc("https://api.appstoreconnect.apple.com/v1/appInfoLocalizations", {"data": {
            "type": "appInfoLocalizations", "attributes": {"locale": locale, **attrs},
            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": app_info_id}}}}})
    print(f"[2] App信息 {locale}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(rr)[:200]}")

# 3. 版本文案层（description/keywords/supportUrl）——keywords在这层
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
existing = {l["attributes"]["locale"]: l["id"] for l in r.get("data", [])}
en_loc = None
for locale, info in LOCALES.items():
    payload = {"type": "appStoreVersionLocalizations", "attributes": {
        "locale": locale, "keywords": info["keywords"], "description": info["description"],
        "supportUrl": "https://postwriter.cn"}}
    if locale in existing:
        patch_attrs = {k: v for k, v in payload["attributes"].items() if k != "locale"}
        if locale == "en-US": en_loc = existing[locale]
        st, rr = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{existing[locale]}",
                     {"data": {"type": "appStoreVersionLocalizations", "id": existing[locale], "attributes": patch_attrs}}, method="PATCH")
    else:
        payload["relationships"] = {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver_id}}}
        st, rr = asc("https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations", {"data": payload})
        if locale == "en-US" and st in (200, 201): en_loc = rr["data"]["id"]
    print(f"[3] 版本文案 {locale}: {'OK' if st in (200, 201) else f'{st} ' + json.dumps(rr)[:200]}")

# 4. 截图上传（en-US locale，APP_IPHONE_67）——照 H 版写法（单对象/列表双兼容）
if not en_loc:
    st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")
    for l in r.get("data", []):
        if l["attributes"]["locale"] == "en-US": en_loc = l["id"]
st, r = asc(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{en_loc}/appScreenshotSets")
set_id = None
for s in r.get("data", []):
    if s["attributes"].get("screenshotDisplayType") == "APP_IPHONE_67":
        set_id = s["id"]; break
if not set_id:
    st, r = asc("https://api.appstoreconnect.apple.com/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": en_loc}}}}})
    if st in (200, 201) and r.get("data"):
        d0 = r["data"]
        set_id = d0[0]["id"] if isinstance(d0, list) else d0["id"]
    else:
        print(f"[4] 截图集创建失败 {st} {json.dumps(r)[:300]}"); sys.exit(1)
print(f"[4] 截图集 {set_id}")
for i in range(1, 4):
    path = os.path.join(STORE, f"shot{i}.png")
    data = open(path, "rb").read()
    md5 = base64.b64encode(hashlib.md5(data).digest()).decode()
    st, r = asc("https://api.appstoreconnect.apple.com/v1/appScreenshots", {
        "data": {"type": "appScreenshots", "attributes": {"fileName": f"shot{i}.png", "fileSize": len(data)},
                 "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    if st not in (200, 201):
        print(f"  shot{i} reserve FAIL {st} {json.dumps(r)[:150]}"); continue
    upload = r["data"]["attributes"]["uploadOperations"][0]
    headers = {hh["name"]: hh["value"] for hh in upload.get("requestHeaders", [])}
    req = urllib.request.Request(upload["url"], data=data, headers=headers, method=upload["method"])
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            up_ok = resp.status in (200, 201)
    except Exception:
        up_ok = False
    if up_ok:
        st2, r2 = asc(f"https://api.appstoreconnect.apple.com/v1/appScreenshots/{r['data']['id']}",
                      {"data": {"type": "appScreenshots", "id": r["data"]["id"],
                                "attributes": {"uploaded": True, "sourceFileChecksum": md5}}}, method="PATCH")
        print(f"  shot{i}: {'OK' if st2 in (200, 201) else 'confirm FAIL'}")
    time.sleep(2)

print("[5] 完成——网页剩：版权/隐私标签/定价供应/审核联系人（API 先做 build 关联/类别/分级）")
