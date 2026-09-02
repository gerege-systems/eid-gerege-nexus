import SwiftUI

/// Нэвтэрсэн үеийн бүрхүүл — ширээний sidebar-ын гар дээрх дүйцэл.
///
/// Хажуугийн цэс биш TabView байгаа нь гоо сайхны сонголт биш: гар дээр
/// эрхий хуруунд хүрэх зурвас доор байдаг. Ширээний нэр томьёо (`Nav_*` түлхүүр,
/// SF Symbol) хэвээр — хоёр клиент нэг зүйлийг нэг нэрээр дуудна.
struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    var body: some View {
        TabView {
            MobileDashboardPage()
                .tabItem { Label(loc.t("Nav_Dashboard"), systemImage: "house") }
            MobileIdPage()
                .tabItem { Label(loc.t("Nav_MyId"), systemImage: "person.text.rectangle") }
            MobileLogsPage()
                .tabItem { Label(loc.t("Nav_Logs"), systemImage: "clock.arrow.circlepath") }
            MobileSettingsPage()
                .tabItem { Label(loc.t("Nav_Settings"), systemImage: "gearshape") }
        }
        .tint(Color.eidAccent)
    }
}

/// Дэлгэц бүрийн нийтлэг хүрээ: гарчиг + гүйлгэх муж + ижил дэвсгэр.
struct MobilePage<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.eidLabel)
                            .foregroundStyle(Color.eidMuted)
                    }
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.eidSurface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// Шошго + утга. Ширээний `WebParityPages.EidField` нь тэр файлын дотор
/// `private` тул энд ижил дүрсийг богиноор давтав — нэг мөрийн дүрсийг
/// хуваалцахын тулд 600 мөрийн ширээний файлыг iOS target руу оруулах нь
/// зөв солилцоо биш.
struct MobileField: View {
    let label: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold, design: mono ? .monospaced : .default))
                .foregroundStyle(Color.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
