# eID Gerege — pure native clients

This directory (`native-apps/`) contains the native client codebases: **iOS/iPadOS** (`GeregeShellKit` SPM + SwiftUI/WKWebView), **windows** (C#/.NET 8 WPF + WebView2), **android** (Kotlin/Compose/WebView), and **macOS** (AppKit/WKWebView).

Each client develops natively from here on. Where a screen is still web, it is
embedded as one of the app's own screens rather than as a second window.

The code came from the core repository ([`open-gerege-nexus/native-apps`](https://github.com/gerege-systems/open-gerege-nexus/blob/main/native-apps))
and is this deployment's copy of it. What is this product's and not the core's:
the domain lines (`*.eid.gerege.mn`), the bundle identifiers (`mn.gerege.eid.*`),
the project files (`eIDGeregeMN.xcodeproj`, `eIDGeregeMN.sln`, `eIDGeregeMN.csproj`)
with the assemblies and binaries they produce, and the visible name **eID Gerege**.
The source packages stay `mn.gerege.nexus` / `GeregeNexusNativeWin` on purpose — the
shell *is* the Gerege Nexus shell, and renaming a package changes nothing a
person or a store can see. Android's `applicationId` and `namespace` therefore
differ, which is what those two settings are for.

---

## 🧱 Two rules that govern every client

**1. One frame.** Each client has exactly one window (macOS/Windows) or one
scene (iOS/Android). Login, the work area, and settings are *screens* that swap
inside that frame — never separate windows. The only thing allowed out of the
frame is a popup: `NSAlert`/`NSMenu`/`NSSavePanel`, `MessageBox` and file
dialogs, `alert`/`confirmationDialog`/share sheets, `BiometricPrompt` and
permission dialogs. `window.open` and `target="_blank"` from the work area do
not open a second webview; the shell hands the URL to the system browser.

Swapping to a native screen hides the webview, it does not remove it. Removing
it rebuilds the webview and the person loses their page, their scroll position
and anything half-typed.

**2. One backend, one domain line per device.** The backend is single. Each
client talks to its own host, and that host serves `/api/v1` too, so calls from
inside the webview are same-origin — the session cookie stays `SameSite=Strict`
and no CORS preflight is ever issued.

| Client | Line | Status |
| --- | --- | --- |
| Browser / PWA | `eid.gerege.mn` | ✅ live |
| macOS, Windows Desktop | `desktop.eid.gerege.mn` | ✅ live |
| iOS / iPadOS, Android mobile / tablet | `mobile.eid.gerege.mn` | ✅ live |
| Kiosk (Windows, Android) | `kiosk.eid.gerege.mn` | ⛔ not provisioned |
| POS (Windows, Android) | `pos.eid.gerege.mn` | ⛔ not provisioned |

The line names the **form factor**, not the platform: a Mac and a Windows box
on the same desk are one line, because a person uses them the same way. Which
client is running is a separate question, answered by `window.GeregeShell`.

`desktop.` and `mobile.` are named explicitly in
[`../nginx/device-lines.eid.gerege.mn.conf`](../nginx/device-lines.eid.gerege.mn.conf)
and share one Let's Encrypt certificate — there is no wildcard here, so a line
this deployment has not asked for does not quietly resolve.

**The kiosk and POS code came along; their lines did not.** Do not ship
`-p:FormFactor=Kiosk`, `-p:FormFactor=POS` or the `kiosk`/`pos` Android flavors
until the four provisioning steps below are done for those hosts. They compile,
which is exactly why the rule below matters.

**When adding a NEW line, do not point a client at it before it resolves.** The
app fails with `A server with the specified hostname could not be found` and
nobody can sign in — this happened once. Do the DNS/nginx/TLS/CORS work first
and change the client's origin constant last. The order and the exact line to
edit are in [`shared/device_lines.json`](shared/device_lines.json)
under `$provisioning`.

Adding a line here is a three-place change: [`shared/device_lines.json`](shared/device_lines.json),
the deploy side ([`../.env.example`](../.env.example)'s `DEVICE_LINE_ORIGINS` plus
[`../nginx/device-lines.eid.gerege.mn.conf`](../nginx/device-lines.eid.gerege.mn.conf)),
and last the client constant. The web half (`frontend/lib/deviceLine.ts`) is the
core's — this deployment runs the core's published shell image and does not
build a frontend.

Both rules are specified in the core's [`docs/SHELL_CONTRACT.md`](https://github.com/gerege-systems/open-gerege-nexus/blob/main/docs/SHELL_CONTRACT.md) §1a and §1b.

---

## 📁 Architecture Overview

```
native-apps/
├── desktop/                     # Ширээний шугам — desktop.eid.gerege.mn
│   ├── macos/                   # macOS Native Shell (Swift 5.10 + AppKit + WKWebView)
│   │   ├── main.swift           # NSApplication Entry Point
│   │   ├── AppDelegate.swift    # App Lifecycle & Native Menu Bar
│   │   ├── MainWindowController.swift    # The single window: ribbon, rail, pane host, footer
│   │   ├── SettingsPaneViewController.swift # Settings as an in-frame NSView, not a window
│   │   ├── NativeIPC.swift      # WKScriptMessageHandler Native IPC Bridge
│   │   └── build.sh             # Swiftc Compilation Script
│   └── windows/                 # Windows Native Shell (C# .NET 8 + WPF + WebView2)
│       ├── eIDGeregeMN.csproj  # .NET 8 Project File
│       ├── App.xaml / App.xaml.cs # WPF Application Lifecycle
│       ├── MainWindow.xaml / MainWindow.xaml.cs # The single window: menu, rail, pane host, footer
│       ├── SettingsPane.xaml / SettingsPane.xaml.cs # Settings as an in-frame UserControl
│       ├── ShellProfile.cs      # Desktop / Kiosk / POS profiles — each names its own line
│       └── NativeIPCBridge.cs   # CoreWebView2.WebMessageReceived IPC Bridge
│
├── mobile/                      # Гарын шугам — mobile.eid.gerege.mn
│   ├── ios/                     # iOS/iPadOS app + shared Swift package
│   │   ├── eIDGeregeMN.xcodeproj # Xcode app project
│   │   ├── Package.swift        # GeregeShellKit, GeregeShellUI, eIDGeregeMNApp
│   │   ├── Sources/             # Native login/settings and WKWebView shell
│   │   └── Tests/               # Swift auth state-machine tests
│   └── android/                 # Android mobile/tablet/kiosk/POS clients
│       ├── core/                # Shared auth/device behavior
│       └── app/                 # Four form-factor flavors
│
├── generated-i18n/              # цөмийн `npm run i18n:export-native`-ийн гаралт
│
└── shared/                      # Shared Specifications & Configurations
    ├── app_config.json          # Window sizing & platform notes
    ├── device_lines.json        # Canonical line → origin map (one backend behind all)
    └── IPC_CONTRACT.md          # Bi-directional JSON IPC Message Contract Specification
```

**Хавтас нь кодын сан, шугам нь хаяг — хоёр нь нэг зүйл биш.** `kiosk` ба
`pos` шугам өөрийн кодгүй: тэдгээр нь Windows-ийн `FormFactor` build ба
Android-ийн flavor. Тиймээс `desktop/windows` доторх киоск build нь `kiosk.`
шугамд үйлчилнэ — код нь Windows, шугам нь киоск. Шугамын бүрэн бүртгэл
`shared/device_lines.json` дотор.

---

## 🚀 Building & Running

### IDE-ээр шууд нээх

- iOS/iPadOS — Xcode-д `ios/eIDGeregeMN.xcodeproj`-ийг нээгээд `eIDGeregeMN` scheme-ийг ажиллуулна. `project.yml` нь XcodeGen-ээр төслийг дахин үүсгэх эх файл.
- macOS — Xcode-д `macos/eIDGeregeMN.xcodeproj`-ийг нээгээд `eIDGeregeMN` scheme-ийг ажиллуулна.
- Android — Android Studio-д `android/` хавтсыг нээнэ. Энд `.xcodeproj` эсвэл
  `.sln` шиг тусдаа project файл БАЙХГҮЙ нь зөв: Gradle төслийн хувьд
  `settings.gradle.kts` бүхий хавтас нь өөрөө төсөл. Wrapper нь repository-д
  орсон тул Gradle тусад нь суулгах шаардлагагүй.
- Windows — Visual Studio 2022-д `windows/eIDGeregeMN.sln`-ийг нээнэ. Solution дотор WPF app болон `GeregeShell.Core` хоёулаа байна.

### 1. macOS Native Shell (Swift + AppKit)

**Prerequisites**: macOS 12+, Xcode Command Line Tools (`swiftc`, `xcrun`)

```bash
# Build the native macOS executable
cd native-apps/desktop/macos
./build.sh

# Run the native macOS application
./eIDGeregeMN
```

### 2. iOS/iPadOS app (SwiftUI + WKWebView)

```bash
cd native-apps/mobile/ios
xcodebuild -project eIDGeregeMN.xcodeproj -scheme eIDGeregeMN \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### 3. Windows Native Shell (C# + WPF + WebView2)

**Prerequisites**: Windows 10/11, .NET 8 SDK

```powershell
# Build and run on Windows
cd native-apps/desktop/windows
dotnet build eIDGeregeMN.csproj -p:FormFactor=Desktop
dotnet build eIDGeregeMN.csproj -p:FormFactor=Kiosk
dotnet build eIDGeregeMN.csproj -p:FormFactor=POS
```

### 4. Android native clients (Kotlin + Compose)

Android Studio-д `native-apps/mobile/android`-ыг нээнэ. Нэг app module дөрвөн
form-factor flavor-тай: `mobile`, `tablet`, `kiosk`, `pos`; auth state machine
нь `:core` модульд байна.

**Prerequisites**: Android SDK. Android Studio-гаар нээхэд `local.properties`-ыг
өөрөө үүсгэдэг тул IDE дотор юу ч хийх шаардлагагүй. Харин **командын мөрнөөс**
барихад тэр файл (эсвэл `ANDROID_HOME`) заавал хэрэгтэй — эс бөгөөс Gradle
`SDK location not found` гэж шууд унана. `local.properties` нь машин бүрт өөр
зам агуулдаг тул git-д ороогүй.

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"   # эсвэл local.properties бичих
./gradlew :core:test
./gradlew :app:assembleMobileDebug
./gradlew :app:assembleTabletDebug :app:assembleKioskDebug :app:assemblePosDebug
```

---

## ⚡ Native Features & Principles Preserved

1. **Native Login + Web Work Area**: Password and eID push are native controls. On success the shell copies `session_token` into the webview cookie store and opens the start route; web `/login` is never rendered in a native client, and the device lines redirect it away server-side.
2. **Native Menu Bar**:
   - macOS Top Menu Bar (`eID Gerege`, `Удирдах`, `Харах`) with native shortcuts (`⌘L`, `⌘,`, `⌘0`, `⌘R`, `⌘Q`).
   - Windows Native Menu Bar (`eID Gerege`, `Удирдах`, `Харах`) with shortcuts (`Ctrl+L`, `Ctrl+,`, `F5`).
3. **In-frame navigation**: a native rail (desktop) or tab bar (mobile) switches between the work area and the shell's own screens. It is deliberately *not* a copy of the tenant app menu — the work area draws that itself, and duplicating it would split one menu across two states.
4. **Bridge Contract v1.4**:
   - `window.GeregeShell` is injected at document start, main-frame only.
   - `auth.reLogin` returns to native login; unknown methods reject.
   - `shell.openPane` lets the work area move to a shell-owned screen without opening anything.
   - the core's [`docs/SHELL_CONTRACT.md`](https://github.com/gerege-systems/open-gerege-nexus/blob/main/docs/SHELL_CONTRACT.md) defines the shared state machine.

## Брэнд ба орчуулга

Нэвтрэх дэлгэцийн бичвэр нь цөмийн i18n-ээс энэ брэндийн нэрээр экспортлогдоно
— гараар засах биш, [`sync-i18n.sh`](sync-i18n.sh)-ыг ажиллуулна:

```bash
native-apps/sync-i18n.sh ../open-gerege-nexus
```

Долоон хэл дээрх `generated-i18n/`, Android `res/values*/auth.xml`, Windows
`Resources/Login*.resx`, iOS `Login.xcstrings` дөрвүүлэн шинэчлэгдэнэ.

Тэмдэг (`brand.png`, `logo.jpg`, `AppIcon`) нь ХАРИН платформынх хэвээр — энэ
бүтээгдэхүүн өөрийн зургаа өгөх хүртэл Gerege Nexus-ийн тэмдэг харагдана.

## Deployment ба update суваг

- macOS: notarized app bundle + Sparkle feed; signing/notarization identity нь
  release environment-ийн secret байна.
- iOS/iPadOS: TestFlight → phased App Store rollout, APNs entitlement/profile.
- Windows: Desktop нь MSIX identity-тэй; Kiosk/POS нь шугамаа асаах хүртэл
  түгээгдэхгүй. Assigned Access template нь
  [`desktop/windows/deployment`](desktop/windows/deployment)-д байна.
- Android: Play managed publishing эсвэл EMM/private APK channel; kiosk нь
  Android Enterprise device-owner + Lock Task ашиглах ба мөн адил шугамаа
  асаах хүртэл түгээгдэхгүй.

Signing certificate, Apple team, Play service account, payment/vendor SDK нь
repository-д хадгалагдахгүй. CI (`.github/workflows/native-clients.yml`) нь бүх
unsigned compile target-ийг шалгана.
