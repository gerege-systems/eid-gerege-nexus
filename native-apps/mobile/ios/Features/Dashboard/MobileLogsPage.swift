import SwiftUI

/// Лог түүх — ширээний `LogsView`-ийн гар дээрх хувилбар.
///
/// Эх сурвалж нь ижил: v3 RP-API нь иргэний бүх session-ий түүхийг өгдөггүй тул
/// энэ жагсаалт бол ЭНЭ ТӨХӨӨРӨМЖ дээрх үйлдлийн локал бүртгэл
/// (`UserDefaults["activity.sessions"]`). Тиймээс утас, мак хоёр өөр өөр
/// жагсаалт харуулах нь ХЭВИЙН — тэдгээр нь өөр өөр төхөөрөмжийн түүх.
struct MobileLogsPage: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    var body: some View {
        MobilePage(title: loc.t("Nav_Logs"),
                   subtitle: loc.pick("Энэ төхөөрөмж дээрх нэвтрэлт, гарын үсгийн бүртгэл",
                                      "Sign-in and signature activity on this device",
                                      "Входы и подписи на этом устройстве",
                                      "本设备上的登录与签名记录")) {
            let sessions = appState.dashboardData?.sessions ?? []
            if sessions.isEmpty {
                AppCard {
                    Text(loc.t("Dashboard_Activity_Empty"))
                        .font(.eidBody)
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                ForEach(sessions) { session in
                    AppCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: session.sessionType == "AUTH" ? "arrow.right.circle" : "signature")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.eidAccent)
                                .frame(width: 34, height: 34)
                                .background(Color.eidAccentSubtle,
                                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.sessionType == "AUTH"
                                     ? loc.t("Dashboard_Activity_Auth") : loc.t("Dashboard_Activity_Sign"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(session.rpName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.textSecondary)
                                Text(MobileDashboardPage.shortDate(session.createdAt))
                                    .font(.eidMonoSmall)
                                    .foregroundStyle(Color.eidMuted)
                            }
                            Spacer(minLength: 0)
                            StatusPill(session.result == "OK"
                                       ? loc.t("Dashboard_Activity_Success") : loc.t("Dashboard_Activity_Failure"),
                                       variant: session.result == "OK" ? .ok : .warn)
                        }
                    }
                }
            }
        }
    }
}
