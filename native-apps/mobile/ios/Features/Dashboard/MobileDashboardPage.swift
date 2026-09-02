import SwiftUI

/// Самбар — ширээний `DashboardPageView`-ийн гар дээрх хувилбар.
///
/// Агуулга нь ЯГ ижил эх сурвалжаас: identity + локал үйл ажиллагааны лог
/// (`AppState.dashboardData`). Ялгаа нь зохион байгуулалт — 4 баганат тор
/// биш 2 баганат, hero нь босоо.
struct MobileDashboardPage: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    var body: some View {
        MobilePage(title: loc.t("Nav_Dashboard"), subtitle: nil) {
            hero
            stats
            activity
        }
    }

    private var hero: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    UserAvatar(photo: appState.dashboardData?.user.photo,
                               initials: initials, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(appState.fullName.isEmpty ? loc.t("Dashboard_Greeting") : appState.fullName)
                            .font(.eidSectionTitle)
                            .foregroundStyle(Color.textPrimary)
                        if !appState.civilID.isEmpty || !appState.nationalID.isEmpty {
                            Text(appState.civilID.isEmpty ? appState.nationalID : appState.civilID)
                                .font(.eidMonoSmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    StatusDot(color: Color.eidSuccess, size: 8)
                    Text(loc.t("Dashboard_StatusBadge"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.eidAccent)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.eidAccentSubtle, in: Capsule())
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            stat(loc.t("Dashboard_Stats_Certificates"), "\(appState.dashboardData?.certificates ?? 0)", "checkmark.seal")
            stat(loc.t("Dashboard_Stats_Logins"), "\(appState.dashboardData?.totalLogins ?? 0)", "arrow.right.circle")
            stat(loc.t("Nav_MyOrganizations"), "\(appState.organizations.count)", "building.2")
            stat(loc.t("Nav_Children"), "\(appState.children.count)", "figure.2.and.child.holdinghands")
        }
    }

    private func stat(_ label: String, _ value: String, _ icon: String) -> some View {
        AppCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.eidAccent)
                Text(value)
                    .font(.eidStatValue)
                    .foregroundStyle(Color.textPrimary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var activity: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Dashboard_Activity_Section"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                let sessions = appState.dashboardData?.sessions.prefix(5) ?? []
                if sessions.isEmpty {
                    Text(loc.t("Dashboard_Activity_Empty"))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                } else {
                    ForEach(Array(sessions), id: \.id) { session in
                        HStack(spacing: 10) {
                            Image(systemName: session.sessionType == "AUTH" ? "arrow.right.circle" : "signature")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.eidAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.rpName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.textPrimary)
                                Text(Self.shortDate(session.createdAt))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer(minLength: 0)
                            StatusPill(session.result, variant: session.result == "OK" ? .ok : .warn)
                        }
                    }
                }
            }
        }
    }

    private var initials: String {
        let parts = appState.fullName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    static func shortDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f.string(from: date)
    }
}
