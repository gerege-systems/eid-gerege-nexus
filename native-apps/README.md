# eID Gerege — native клиентүүд

Гурван клиент, нэг бүтээгдэхүүн: **macOS** (`desktop/macos`), **iOS/iPadOS**
(`mobile/ios`), **Android** (`mobile/android`). Гурвуулаа eID Gerege
байрлуулалтын иргэн рүү харсан клиент — вэб бүрхүүл БИШ, native апп.

## Гурван зарчим (гурвуулан дээр ижил)

**1. Клиентэд secret байхгүй.** Бүх дуудлага өөрийн web backend-ийн нийтийн
`/api/…` route-уудаар явна — хөтөчтэй яг ижил зам. RP-ийн нууцыг зөвхөн web
сервер барина. Тиймээс аппыг задалж үзсэн хүнд авах юм алга.

**2. Identity нь snapshot, session биш.** Bearer token байхгүй: нэвтрэлтийн
үр дүн (`documentNumber`, нэр, иргэний дугаар) нь дараагийн үйлдлийн бариул
бөгөөд Keychain (Apple) / Android Keystore-оор шифрлэгдэж хадгалагдана. Апп
сүлжээгүй ч нээгдэнэ — зөвхөн шинэ өгөгдөл татагдахгүй.

**3. Нэр МОНГОЛООР.** Гэрчилгээний subject дэх нэр нь латин галиг
(«ERDENEBAT TSENDDORJ») тул дэлгэцэнд харагдах нэрийг `POST /api/dashboard`
(XYP-ийн хураангуй) -аас авна. Гурван клиент энэ дүрмийг нэвтрэлтийн урсгал
дотроо хэрэгжүүлдэг — эхний кадраасаа зөв нэр.

## Нэвтрэлт — платформ бүрт өөр, session нь ижил

| Клиент | Хэрхэн | Яагаад |
|---|---|---|
| macOS | QR + РД push | Зөвшөөрөгч нь ХӨРШ утас |
| iOS / Android | app-to-app (`geregesmartid://approve?sessionId=…`), fallback РД push | Зөвшөөрөгч нь ӨӨРӨӨ тэр утас — QR-аа өөрөө скан хийж чадахгүй |

Гурвуулан ижил `POST /api/start` → `GET /api/status` poll дээр суудаг: session
нь хэн зөвшөөрснөөс үл хамааран ижил тул app-to-app-д НЭГ Ч шинэ backend
endpoint нэмээгүй. eID Mongolia апп суугаагүй бол РД push зам үлдэнэ (утас
дээрх схемийг асуухын тулд iOS `LSApplicationQueriesSchemes`, Android
`<queries>` блокт бүртгэсэн байх ЁСТОЙ — эс бөгөөс OS «суугаагүй» гэж худал
хэлнэ).

## Код хуваалцах — хуулбар биш

```
desktop/macos/            macOS апп + ХУВААЛЦСАН давхаргууд
  Core/Network            AppConfig, Endpoints, APIClient
  Core/Keychain           identity snapshot
  App/AppState.swift      төлөв, локал лог
  Design/                 өнгө, фонт, дүрсүүд
  Presentation/           локализаци (7 хэл)
  Core/Token, Core/Esign   ← ЗӨВХӨН ширээний (PKCS#11, ws гүүр)
mobile/ios/               iOS апп — дээрхийг `project.yml`-ээр ШУУД эх файлаар нь оруулна
mobile/android/           Android апп — өнгө, орчуулгыг ҮҮСГЭНЭ (scripts/gen_from_swift.py)
```

iOS нь ширээний файлуудыг хуулдаггүй, ШУУД эх файлаар нь компайл хийдэг тул
endpoint, өнгө, орчуулга хоёр дээр салбарлах боломжгүй. Android өөр хэл дээр
тул тэр замыг явж чадахгүй — оронд нь `scripts/gen_from_swift.py` нь
`Design/Colors.swift` → `EidColors.kt`, локализацийн каталог →
`res/values*/eid_strings.xml` болгож үүсгэнэ. CI нь скриптийг дахин ажиллуулж
ялгаа гарвал улаан болно.

## Барих

```bash
# macOS (Xcode 16+, xcodegen)
cd desktop/macos && ./build.sh

# iOS/iPadOS
cd mobile/ios && ./build.sh
DESTINATION='generic/platform=iOS' ./build.sh     # төхөөрөмжид

# Android (ANDROID_HOME эсвэл local.properties шаардлагатай)
cd mobile/android && ./gradlew assembleDebug
python3 scripts/gen_from_swift.py                 # өнгө/орчуулгыг дахин үүсгэх
```

`.xcodeproj` нь артефакт (`.gitignore`) — `project.yml`-ийг засаж `build.sh`
ажиллуулна. CI: `.github/workflows/native-clients.yml` гурвууланг компайл хийнэ.

## Төхөөрөмжийн шугам

| Клиент | Шугам | Төлөв |
|---|---|---|
| macOS | `desktop.eid.gerege.mn` | ⏳ nginx/TLS шалгах |
| iOS, Android | `mobile.eid.gerege.mn` | ⏳ nginx/TLS шалгах |

Бүртгэл ба асаах дараалал: [`shared/device_lines.json`](shared/device_lines.json)
→ `$provisioning`. Клиентийн доторх хаягийг ХАМГИЙН СҮҮЛД солино — эсрэгээр
явбал апп байхгүй host руу чиглэж унана.

## Хараахан хийгээгүй (утсан дээр)

Гарын үсэг (PDF), гэрчилгээ шалгах, платформын webview таб, биометр түгжээ,
push мэдэгдэл. Ширээн дээр эдгээр бий; гар дээр суурь урсгал (нэвтрэлт,
самбар, ID, лог, тохиргоо) эхэлж ирлээ.
