import SwiftUI

/// Миний ID — ширээний `MyIdView`-ийн гар дээрх хувилбар.
///
/// Ижил эх сурвалж (`AppState.dashboardData?.user`), ижил талбарууд. Ялгаа нь
/// зохион байгуулалт: гар дээр хоёр баганат тор биш дараалсан мөр.
struct MobileIdPage: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    private var user: DashboardUser? { appState.dashboardData?.user }

    var body: some View {
        MobilePage(title: loc.t("Nav_MyId"),
                   subtitle: loc.pick("Танай иргэний цахим үнэмлэхний нэгдсэн профайл",
                                      "Your unified e-ID profile",
                                      "Ваш единый профиль e-ID",
                                      "您的统一 e-ID 档案")) {
            if let user {
                identityCard(user)
                certificateCard(user)
                if !appState.organizations.isEmpty { organizationsCard }
                if !appState.children.isEmpty { childrenCard }
            } else {
                AppCard {
                    Text(loc.t("Dashboard_Activity_Empty"))
                        .font(.eidBody)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func identityCard(_ user: DashboardUser) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    UserAvatar(photo: user.photo, initials: initials(user.displayName), size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Color.textPrimary)
                        StatusPill(user.status.lowercased() == "active"
                                   ? loc.pick("Идэвхтэй", "Active", "Активен", "有效") : user.status,
                                   variant: user.status.lowercased() == "active" ? .ok : .warn)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                MobileField(label: loc.pick("Регистрийн дугаар", "Registration number",
                                         "Регистрационный номер", "登记号"),
                         value: user.nationalId.isEmpty ? "—" : user.nationalId, mono: true)
                if let civil = user.civilId, !civil.isEmpty {
                    MobileField(label: loc.pick("Иргэний бүртгэлийн дугаар", "Civil ID",
                                             "Гражданский ID", "公民号"),
                             value: civil, mono: true)
                }
            }
        }
    }

    private func certificateCard(_ user: DashboardUser) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc.pick("Гэрчилгээ", "Certificate", "Сертификат", "证书").uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                MobileField(label: loc.pick("Түвшин", "Level", "Уровень", "等级"),
                         value: user.kycLevel.isEmpty ? "—" : user.kycLevel)
                MobileField(label: loc.pick("Баримтын дугаар", "Document number",
                                         "Номер документа", "文件号"),
                         value: appState.documentNumber.isEmpty ? "—" : appState.documentNumber, mono: true)
            }
        }
    }

    private var organizationsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Nav_MyOrganizations"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                ForEach(appState.organizations) { org in
                    HStack(spacing: 10) {
                        Image(systemName: "building.2")
                            .font(.system(size: 13)).foregroundStyle(Color.eidAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(org.orgName).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(org.orgRegister).font(.eidMonoSmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: 0)
                        StatusPill(org.rightType, variant: .accent)
                    }
                }
                // Ширээнийхтэй ижил дүрэм: энэ жагсаалт ЗӨВХӨН УНШИХ.
                EidReadOnlyHint()
            }
        }
    }

    private var childrenCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc.t("Nav_Children"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                ForEach(appState.children) { child in
                    HStack(spacing: 10) {
                        Image(systemName: "figure.child")
                            .font(.system(size: 13)).foregroundStyle(Color.eidAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.name).font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(child.regNo).font(.eidMonoSmall)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: 0)
                        StatusPill(child.registered
                                   ? loc.pick("Бүртгэлтэй", "Registered", "Зарегистрирован", "已注册")
                                   : loc.pick("Хүлээгдэж буй", "Pending", "Ожидает", "待处理"),
                                   variant: child.registered ? .ok : .warn)
                    }
                }
                EidReadOnlyHint()
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

/// «Энэ жагсаалтыг зөвхөн утсан дээрх eID апп өөрчилнө» — ширээний
/// `EidReadOnlyNote`-ийн богино хувилбар. Гар дээр газар бага тул нэг мөр.
struct EidReadOnlyHint: View {
    @ObservedObject private var loc = LocalizationService.shared
    var body: some View {
        Text(loc.pick("Зөвхөн харуулна — өөрчлөлтийг eID Mongolia апп дотроос (PIN2) хийнэ.",
                      "Read-only — changes happen in the eID Mongolia app (PIN2).",
                      "Только просмотр — изменения выполняются в приложении eID Mongolia (PIN2).",
                      "仅供查看——更改请在 eID Mongolia 应用中完成（PIN2）。"))
            .font(.system(size: 11))
            .foregroundStyle(Color.eidMuted)
    }
}
