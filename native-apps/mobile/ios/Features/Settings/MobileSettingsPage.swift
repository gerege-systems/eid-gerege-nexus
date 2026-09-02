import SwiftUI

/// Тохиргоо — ширээний `SettingsSheetView`-ийн гар дээрх хувилбар.
///
/// Ширээнийхээс ХАСАГДСАН зүйлс нь утсан дээр утгагүй байдгаараа: нэвтрэхэд
/// автоматаар асах (login item), арын горим, ESIGN токен (ws гүүр нь ижил
/// машин дээрх хөтчид зориулсан). Үлдсэн нь ижил: төрх, хэл, сервер, тухай.
struct MobileSettingsPage: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared
    @AppStorage("ui.theme") private var theme: String = "system"
    @AppStorage(AppConfig.baseURLKey) private var apiURL: String = ""

    @State private var confirmLogout = false

    var body: some View {
        MobilePage(title: loc.t("Nav_Settings"), subtitle: nil) {
            themeCard
            languageCard
            serverCard
            aboutCard
            logoutButton
        }
        .preferredColorScheme(colorScheme)
    }

    private var themeCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Settings_Theme"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Picker("", selection: $theme) {
                    Text(loc.t("Settings_Theme_System")).tag("system")
                    Text(loc.t("Settings_Theme_Light")).tag("light")
                    Text(loc.t("Settings_Theme_Dark")).tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var languageCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Settings_Language"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        loc.setLanguage(lang)
                    } label: {
                        HStack {
                            Text(lang.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if loc.language == lang {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.eidAccent)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if lang != AppLanguage.allCases.last { Divider() }
                }
            }
        }
    }

    /// Сервер солих нь ЗӨВХӨН туршилтад. Хоосон бол энэ байрлуулалтын
    /// гарын шугам (`mobile.eid.gerege.mn`) — `AppConfig.baseURL`.
    private var serverCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.pick("Сервер", "Server", "Сервер", "服务器"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                TextField(AppConfig.baseURL, text: $apiURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .font(.eidMono)
                Text(loc.pick("Хоосон бол анхдагч: \(AppConfig.baseURL)",
                              "Empty means the default: \(AppConfig.baseURL)",
                              "Пусто — по умолчанию: \(AppConfig.baseURL)",
                              "留空则使用默认值：\(AppConfig.baseURL)"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.eidMuted)
            }
        }
    }

    private var aboutCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.pick("Тухай", "About", "О приложении", "关于"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                MobileField(label: loc.pick("Хувилбар", "Version", "Версия", "版本"),
                            value: "\(AppConfig.brandName) v\(version)", mono: true)
                MobileField(label: loc.pick("Холбогдож буй хост", "Connected host",
                                            "Подключённый хост", "连接的主机"),
                            value: URL(string: AppConfig.baseURL)?.host ?? AppConfig.baseURL, mono: true)
                Link(destination: URL(string: "mailto:support@eidmongol.mn")!) {
                    Label(loc.t("Nav_Support"), systemImage: "headphones")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.eidAccent)
                }
            }
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            confirmLogout = true
        } label: {
            Label(loc.t("Nav_Logout"), systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondary(fullWidth: true, height: 46))
        .confirmationDialog(loc.t("Nav_Logout"), isPresented: $confirmLogout, titleVisibility: .visible) {
            Button(loc.t("Nav_Logout"), role: .destructive) { appState.logout() }
            Button(loc.t("Login_Cancel"), role: .cancel) {}
        }
    }

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
