import SwiftUI
import UIKit

/// Утаснаас нэвтрэх — ширээний `LoginView`-ийн гар дээрх хувилбар.
///
/// **Яагаад ширээнийхээс өөр вэ.** Мак дээр QR/РД push-ыг ХӨРШ утас
/// зөвшөөрдөг. Утсан дээр тэр зөвшөөрөгч нь өөрөө байгаа тул QR харуулах нь
/// утгагүй — өөрийгөө скан хийх боломжгүй. Оронд нь ижил session-ийг
/// **app-to-app**-аар eID Mongolia апп руу шилжүүлнэ:
///
///   1. `POST /api/start` → `{sessionId, vc, pollToken}` (мак-тай ЯГ ижил route)
///   2. `eidmongolia://approve?sessionId=<sid>` нээнэ — eID апп зөвшөөрөл асууна
///   3. Энэ апп нь `/api/status`-ыг цаанаа poll хийж, хүн буцаж ирэхэд бэлэн
///
/// Нэг ч шинэ backend endpoint нэмээгүй: session нь хэн зөвшөөрснөөс үл хамааран
/// ижил. eID апп суугаагүй бол РД push руу шилжинэ — тэр үед хүн өөр
/// төхөөрөмж дээрээ зөвшөөрнө.
struct MobileLoginView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    private enum Phase: Equatable { case idle, starting, waiting, success, error }

    @State private var phase: Phase = .idle
    @State private var register = ""
    @State private var verificationCode = ""
    @State private var errorMessage = ""
    @State private var signedInName = ""
    @State private var task: Task<Void, Never>?
    @State private var showRegisterField = false

    /// eID Mongolia аппын deep link. Схемийг Info.plist-ийн
    /// `LSApplicationQueriesSchemes`-д мөн бүртгэсэн байх ёстой.
    private static let appSchemes = ["eidmongolia", "geregesmartid"]

    var body: some View {
        // Богино агуулгыг ГОЛЛУУЛЖ, гар гарч ирэхэд ГҮЙЛГЭНЭ. Зөвхөн ScrollView
        // байвал агуулга дээд ирмэг дээр наалдаж, доогуураа хагас дэлгэц хоосон
        // үлддэг; зөвхөн VStack байвал регистр бичих үед гар талбарыг дардаг.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    brand
                    card
                    if !errorMessage.isEmpty {
                        InlineBanner(text: errorMessage, variant: .error)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(Color.eidSurface.ignoresSafeArea())
        .onDisappear { task?.cancel() }
    }

    // MARK: - Хэсгүүд

    private var brand: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.eidAccent)
                .frame(width: 76, height: 76)
                .background(Color.eidAccentSubtle, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(AppConfig.brandName)
                .font(.eidHeroTitle)
                .foregroundStyle(Color.textPrimary)
            Text(loc.t("Login_Subtitle"))
                .font(.eidLabel)
                .foregroundStyle(Color.eidMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var card: some View {
        AppCard {
            switch phase {
            case .idle, .error:   choices
            case .starting:       progress(loc.t("Login_Initiate_Loading"))
            case .waiting:        waitingBody
            case .success:        successBody
            }
        }
    }

    private var choices: some View {
        VStack(spacing: 14) {
            Button {
                startAppToApp()
            } label: {
                Label(loc.pick("eID аппаар нэвтрэх", "Sign in with the eID app",
                               "Войти через приложение eID", "使用 eID 应用登录"),
                      systemImage: "arrow.up.forward.app.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(fullWidth: true, height: 46))

            if showRegisterField || !isEidAppInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.t("Login_NationalId"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    TextField(loc.t("Login_NationalId_Placeholder"), text: $register)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .font(.eidMono)
                    Button {
                        startPush()
                    } label: {
                        Label(loc.pick("Регистрээр мэдэгдэл илгээх", "Send a push by registration number",
                                       "Отправить push по регистрационному номеру", "按登记号发送推送"),
                              systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondary(fullWidth: true, height: 42))
                    .disabled(register.trimmingCharacters(in: .whitespaces).count < 8)
                }
            } else {
                Button {
                    showRegisterField = true
                } label: {
                    Text(loc.pick("Өөр төхөөрөмж дээрээ зөвшөөрөх",
                                  "Approve on another device",
                                  "Подтвердить на другом устройстве",
                                  "在其他设备上确认"))
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.eidAccent)
            }
        }
    }

    private var waitingBody: some View {
        VStack(spacing: 16) {
            progress(loc.t("Login_Waiting_Subtitle"))
            if !verificationCode.isEmpty {
                VStack(spacing: 6) {
                    Text(loc.t("Login_VerificationCode"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                    VerificationCodeRow(code: verificationCode)
                    Text(loc.pick("Аппд харагдах кодтой тулгана уу.",
                                  "Match this with the code shown in the app.",
                                  "Сравните с кодом в приложении.",
                                  "请与应用中显示的代码核对。"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.eidMuted)
                        .multilineTextAlignment(.center)
                }
            }
            Button(loc.t("Login_Cancel")) {
                task?.cancel()
                phase = .idle
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.eidMuted)
            .font(.system(size: 13))
        }
    }

    private var successBody: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color.eidSuccess)
            Text(loc.t("Login_Success_Title"))
                .font(.eidSectionTitle)
                .foregroundStyle(Color.textPrimary)
            if !signedInName.isEmpty {
                Text(signedInName)
                    .font(.eidBody)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func progress(_ text: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.eidLabel)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Label(host, systemImage: "network")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.eidMuted.opacity(0.8))
            Text("\(AppConfig.brandName) v\(appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(Color.eidMuted.opacity(0.7))
        }
    }

    // MARK: - Урсгалууд

    /// eID апп суусан эсэх. Схемүүд Info.plist-д бүртгэгдээгүй бол iOS үргэлж
    /// `false` буцаана — тэр тохиолдолд ч РД push зам нээлттэй тул апп гацахгүй.
    private var isEidAppInstalled: Bool {
        Self.appSchemes.contains { scheme in
            URL(string: "\(scheme)://approve").map { UIApplication.shared.canOpenURL($0) } ?? false
        }
    }

    private func startAppToApp() {
        run { () -> (String, String, String)? in
            let response: StartResponse = try await APIClient.shared.request(.start)
            let sid = response.sessionId
            await MainActor.run {
                appState.sessionID = sid
                verificationCode = response.vc ?? ""
                phase = .waiting
            }
            await openEidApp(sessionID: sid)
            return (sid, response.pollToken ?? "", "")
        }
    }

    private func startPush() {
        let typed = register.trimmingCharacters(in: .whitespaces).uppercased()
        run { () -> (String, String, String)? in
            let response: LoginNotifyResponse = try await APIClient.shared
                .request(.loginNotify(register: typed))
            await MainActor.run {
                appState.sessionID = response.sessionId
                verificationCode = response.vc ?? ""
                phase = .waiting
            }
            return (response.sessionId, response.pollToken ?? "", typed)
        }
    }

    /// Session эхлүүлээд poll хийх нийтлэг бүрхүүл — хоёр зам ижил төгсгөлтэй.
    private func run(_ start: @escaping () async throws -> (String, String, String)?) {
        task?.cancel()
        errorMessage = ""
        phase = .starting
        task = Task {
            do {
                guard let (sessionID, pollToken, typedID) = try await start() else { return }
                let status = try await APIClient.shared.waitForAuth(sessionID: sessionID, pollToken: pollToken)
                await finish(status, sessionID: sessionID, pollToken: pollToken, typedID: typedID)
            } catch is CancellationError {
                // Хүн цуцаллаа.
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .error
                }
            }
        }
    }

    /// eID Mongolia апп руу шилжүүлнэ. Аль схем нээгдэхийг iOS шийднэ —
    /// `geregesmartid` нь backend-ийн хуучин схем, `eidmongolia` нь rebrand.
    @MainActor
    private func openEidApp(sessionID: String) async {
        for scheme in Self.appSchemes {
            guard let url = URL(string: "\(scheme)://approve?sessionId=\(sessionID)"),
                  UIApplication.shared.canOpenURL(url) else { continue }
            await UIApplication.shared.open(url)
            return
        }
        // Апп олдсонгүй — хүн өөр төхөөрөмж дээрээ зөвшөөрөх зам руу.
        showRegisterField = true
        errorMessage = loc.pick(
            "eID Mongolia апп олдсонгүй. Регистрийн дугаараар мэдэгдэл илгээж, өөр төхөөрөмж дээрээ зөвшөөрнө үү.",
            "The eID Mongolia app was not found. Send a push by registration number and approve on another device.",
            "Приложение eID Mongolia не найдено. Отправьте push по регистрационному номеру и подтвердите на другом устройстве.",
            "未找到 eID Mongolia 应用。请按登记号发送推送，并在其他设备上确认。")
    }

    /// Ширээний `handleAuthResult`-тай ЯГ ижил дүрэм: нэрийг XYP-ийн
    /// хураангуйгаас МОНГОЛООР авч, identity-г Keychain-д хадгална.
    private func finish(_ status: StatusResponse, sessionID: String,
                        pollToken: String, typedID: String) async {
        guard status.isComplete, status.isOK,
              let doc = status.documentNumber, !doc.isEmpty else {
            await MainActor.run {
                errorMessage = status.error?.isEmpty == false
                    ? (status.error ?? "")
                    : loc.pick("Баталгаажуулалт амжилтгүй.", "Verification failed.",
                               "Проверка не удалась.", "验证失败。")
                phase = .error
            }
            return
        }
        let summary: PersonSummaryResponse? = try? await APIClient.shared
            .request(.dashboard(sessionID: sessionID, pollToken: pollToken))
        let name = summary?.mongolianName ?? (status.name ?? "")
        let civil = status.idNumber ?? ""
        let identity = StoredIdentity(
            documentNumber: doc,
            fullName: name,
            civilID: civil,
            nationalID: typedID,
            certificateLevel: status.certificateLevel ?? "QUALIFIED",
            loginAt: ISO8601DateFormatter().string(from: Date())
        )
        await MainActor.run {
            signedInName = name
            phase = .success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                appState.didLogin(identity: identity)
                appState.loadPersonExtras(sessionID: sessionID, pollToken: pollToken)
            }
        }
    }

    private var host: String { URL(string: AppConfig.baseURL)?.host ?? AppConfig.baseURL }
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
