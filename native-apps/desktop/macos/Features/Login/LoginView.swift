import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

/// Нэвтрэх дэлгэц — split layout (dark brand panel зүүн, login card баруун).
/// First-party урсгал (browser-тэй яг ижил, web-ийн нийтийн route-ууд):
///   • QR: `POST /api/start` → QR = sessionId, `vc` кодыг дэлгэцэнд харуулна
///     → утсаараа скан → PIN1.
///   • РД push: `POST /api/login-notify {register}` → `vc` харуулна →
///     утсанд push → PIN1.
/// Хоёулаа `GET /api/status?sessionId=` poll-оор дуусна; web сервер гарын
/// үсгийг криптограф баталгаажуулаад нэр + иргэний дугаар + documentNumber-ийг
/// задалж өгнө — тэр нь identity болно.
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var loc = LocalizationService.shared

    @State private var mode: LoginTab = .nationalID
    @State private var phase: AuthPhase = .idle

    // Inputs
    @State private var nationalID = ""

    // Auth display
    @State private var verificationCode = ""
    @State private var errorMessage = ""
    @State private var countdown = 300
    @State private var pollTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?

    // QR
    @State private var qrImage: NSImage?

    // Signed-in identity (success state)
    @State private var signedInName = ""
    @State private var signedInNationalId = ""
    @State private var signedInKycLevel = ""

    var body: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 820
            HStack(spacing: 0) {
                if wide {
                    leftPanel
                        .frame(width: proxy.size.width * 5 / 11)
                }
                rightPanel
                    .frame(maxWidth: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: wide)
        }
        .frame(minWidth: 480, minHeight: 560)
        .onDisappear {
            pollTask?.cancel()
            countdownTask?.cancel()
        }
    }

    // MARK: - Left panel — diagonal dark gradient + bokeh + big logo

    private var leftPanel: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "091540"), location: 0.0),
                    .init(color: Color(hex: "0E2060"), location: 0.45),
                    .init(color: Color(hex: "1A3A8F"), location: 1.0),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color.brand400.opacity(0.16), .clear]),
                    center: .center, startRadius: 0, endRadius: 260
                ))
                .frame(width: 520, height: 520)
                .offset(x: 220, y: -220)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color(hex: "818CF8").opacity(0.13), .clear]),
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(x: -150, y: 150)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            gradient: Gradient(colors: [Color.brand400.opacity(0.55), .clear]),
                            center: .center, startRadius: 0, endRadius: 60
                        ))
                        .frame(width: 100, height: 100)
                        .blur(radius: 18)
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                VStack(spacing: 6) {
                    Text("e-ID Mongolia")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Text(loc.t("Login_Left_Subtitle"))
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color(hex: "93C5FD"))
                }
            }
            .offset(y: -40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Text(loc.t("Login_Left_Safe"))
                        .foregroundStyle(.white)
                    Text(" & ")
                        .foregroundStyle(Color.brand400)
                    Text(loc.t("Login_Left_Reliable"))
                        .foregroundStyle(.white)
                }
                .font(.system(size: 21, weight: .bold))

                Text(loc.t("Login_Left_Description"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "7CAEE8"))
                    .lineSpacing(4)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .clipped()
    }

    // MARK: - Right panel — light bg + login card

    private var rightPanel: some View {
        ZStack {
            Color.eidSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                centeredContent
                Spacer()
                footer
                    .padding(.bottom, 16)
            }
        }
    }

    private var centeredContent: some View {
        VStack(spacing: 20) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            loginCard
                .frame(maxWidth: 450)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Login card

    private var loginCard: some View {
        VStack(spacing: 0) {
            cardContent
        }
        .padding(28)
        .background(Color.eidCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.eidCardStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 10)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch phase {
        case .idle, .error:
            idleOrErrorContent
        case .loading:
            loadingContent
        case .waiting:
            waitingContent
        case .success:
            successContent
        }
    }

    // MARK: - Idle/error content (2 tabs + form + footer links)

    private var idleOrErrorContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.t("Login_Title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                Text(loc.t("Login_Subtitle"))
                    .font(.eidLabel)
                    .foregroundStyle(Color.eidMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            tabSwitcher

            if !errorMessage.isEmpty {
                InlineBanner(text: errorMessage, variant: .error)
            }

            switch mode {
            case .nationalID: nationalIDSection
            case .qr:         qrSection
            }

            Divider().padding(.vertical, 6)

            HStack(spacing: 16) {
                Button(loc.t("Login_Footer_NewAccount")) {
                    if let url = URL(string: AppConfig.baseURL) { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.link)
                .foregroundStyle(Color.eidAccent)

                Button(loc.t("Login_Footer_Help")) {
                    if let url = URL(string: AppConfig.baseURL) { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.link)
                .foregroundStyle(Color.eidAccent)
            }
            .font(.eidLabel)
            .padding(.top, 4)
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            tabButton(loc.t("Login_Tab_NationalId"), isActive: mode == .nationalID) { selectMode(.nationalID) }
            tabButton(loc.t("Login_Tab_Qr"),         isActive: mode == .qr)         { selectMode(.qr) }
        }
        .padding(4)
        .background(Color.eidMuted.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tabButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? Color.textPrimary : Color.eidMuted)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isActive ? Color.eidCardBackground : Color.clear)
                        .shadow(color: isActive ? .black.opacity(0.10) : .clear, radius: 3, y: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - National ID input

    private var nationalIDSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t("Login_NationalId_PushHint"))
                .font(.eidLabel)
                .foregroundStyle(Color.eidMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(loc.t("Login_NationalId"))
                    .font(.eidLabel)
                    .foregroundStyle(Color.eidMuted)
                TextField(loc.t("Login_NationalId_Placeholder"), text: $nationalID)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.eidMuted.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.eidCardStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit { initiateLogin() }
            }

            Button(action: initiateLogin) {
                Text(loc.t("Login_Initiate"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.primary(fullWidth: true, height: 50))
            .disabled(nationalID.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Verification code block (digit boxes + countdown)

    @ViewBuilder
    private var verificationCodeBlock: some View {
        if !verificationCode.isEmpty {
            VStack(spacing: 10) {
                Text(loc.t("Login_VerificationCode"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.eidMuted)
                    .kerning(0.8)
                VerificationCodeRow(code: verificationCode, size: CGSize(width: 44, height: 52))
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(String(format: "%d:%02d", countdown / 60, countdown % 60))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                    Text("·")
                    ProgressView().controlSize(.small)
                    Text(loc.t("Login_Waiting_Countdown"))
                }
                .font(.eidLabel)
                .foregroundStyle(countdown < 60 ? Color.eidDanger : Color.eidMuted)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - QR section

    private var qrSection: some View {
        VStack(spacing: 14) {
            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.eidCardStroke, lineWidth: 1)
                    )

                Text(loc.t("Login_Qr_Hint"))
                    .font(.eidLabel)
                    .foregroundStyle(Color.eidMuted)
                    .multilineTextAlignment(.center)

                verificationCodeBlock
            } else if phase == .error {
                // Алдаа гарсан үед spinner эргүүлэх нь худал — QR хэзээ ч гарахгүй. Дахин
                // оролдох зам өгнө (эс бөгөөс хэрэглэгч аппаа хаахаас өөр аргагүй болно).
                Button(action: initQR) {
                    Label("Дахин оролдох", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 220)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 220)
            }
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(loc.t("Login_Initiate_Loading"))
                .font(.eidBody)
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Waiting (verification code + countdown)

    private var waitingContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.eidAccent)
                Text(loc.t("Login_Waiting_Title"))
                    .font(.eidSectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Text(loc.t("Login_Waiting_Subtitle"))
                    .font(.eidLabel)
                    .foregroundStyle(Color.eidMuted)
                    .multilineTextAlignment(.center)
            }

            if !verificationCode.isEmpty {
                VStack(spacing: 8) {
                    Text(loc.t("Login_VerificationCode"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.eidMuted)
                        .kerning(0.8)
                    VerificationCodeRow(code: verificationCode, size: CGSize(width: 48, height: 56))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(String(format: "%d:%02d", countdown / 60, countdown % 60))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
            .foregroundStyle(countdown < 60 ? Color.eidDanger : Color.eidMuted)

            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Хүлээж байна...")
                    .font(.eidLabel)
                    .foregroundStyle(Color.eidMuted)
            }

            Button(loc.t("Login_Cancel")) {
                cancelWaiting()
            }
            .buttonStyle(.secondary(fullWidth: true, height: 38))
        }
        .padding(.vertical, 8)
    }

    // MARK: - Success

    private var successContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.bannerSuccessBG)
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.bannerSuccessIcon)
            }

            Text(loc.t("Login_Success_Title"))
                .heroTitleStyle()

            ProgressView().controlSize(.small)

            Text(loc.t("Login_Success_Subtitle"))
                .font(.eidLabel)
                .foregroundStyle(Color.eidMuted)

            if !signedInName.isEmpty || !signedInNationalId.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(spacing: 6) {
                    if !signedInName.isEmpty {
                        Text(signedInName)
                            .font(.eidSectionTitle)
                            .foregroundStyle(Color.textPrimary)
                    }
                    if !signedInNationalId.isEmpty {
                        Text("\(loc.t("Login_Result_NationalId")): \(signedInNationalId)")
                            .font(.eidMonoSmall)
                            .foregroundStyle(Color.eidMuted)
                    }
                    if !signedInKycLevel.isEmpty {
                        Text("\(loc.t("Login_Result_KycLabel")): \(signedInKycLevel)")
                            .font(.eidLabel)
                            .foregroundStyle(Color.eidMuted)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Gerege Systems LLC © 2026")
            .font(.eidLabel)
            .foregroundStyle(Color.eidMuted)
    }

    // MARK: - Mode switch

    private func selectMode(_ newMode: LoginTab) {
        guard newMode != mode else { return }
        cancelWaiting()
        mode = newMode
        errorMessage = ""
        verificationCode = ""

        switch newMode {
        case .qr:
            initQR()
        case .nationalID:
            qrImage = nil
        }
    }

    // MARK: - Push flow (`POST /api/login-notify`)

    private func initiateLogin() {
        let id = nationalID.trimmingCharacters(in: .whitespaces).uppercased()
        guard !id.isEmpty else { return }

        phase = .loading
        errorMessage = ""

        pollTask = Task {
            do {
                let response: LoginNotifyResponse = try await APIClient.shared.request(
                    .loginNotify(register: id)
                )
                await MainActor.run {
                    verificationCode = response.vc ?? ""
                    appState.sessionID = response.sessionId
                    countdown = 300
                    phase = .waiting
                    startCountdown()
                }
                let status = try await APIClient.shared.waitForAuth(
                    sessionID: response.sessionId,
                    pollToken: response.pollToken ?? ""
                )
                await handleAuthResult(status, sessionID: response.sessionId,
                                       pollToken: response.pollToken ?? "", typedID: id)
            } catch is CancellationError {
                // Cancelled by tab switch — ignore.
            } catch let e as URLError where e.code == .cancelled {
                // URLSession request cancelled by the same task cancel.
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .error
                }
            }
        }
    }

    // MARK: - QR flow (`POST /api/start`)

    private func initQR() {
        pollTask?.cancel()
        qrImage = nil
        errorMessage = ""

        pollTask = Task {
            do {
                let response: StartResponse = try await APIClient.shared.request(.start)
                // Web-тэй ижил: QR-д `qr` (= sessionId)-г шууд кодлоно —
                // утасны app скан хийгээд энэ session-ийг зөвшөөрнө.
                let image = generateQRCode(from: response.qr)
                await MainActor.run {
                    appState.sessionID = response.sessionId
                    verificationCode = response.vc ?? ""
                    qrImage = image
                    countdown = 300
                    startCountdown()
                }
                let status = try await APIClient.shared.waitForAuth(
                    sessionID: response.sessionId,
                    pollToken: response.pollToken ?? ""
                )
                await handleAuthResult(status, sessionID: response.sessionId,
                                       pollToken: response.pollToken ?? "", typedID: "")
            } catch is CancellationError {
                // Tab switch / re-init cancelled the in-flight task.
            } catch let e as URLError where e.code == .cancelled {
                // URLSession request cancelled by the same task cancel.
            } catch {
                await MainActor.run {
                    errorMessage = "QR код үүсгэхэд алдаа: \(error.localizedDescription)"
                    phase = .error
                }
            }
        }
    }

    // MARK: - Shared

    private func handleAuthResult(_ status: StatusResponse, sessionID: String, pollToken: String, typedID: String) async {
        guard status.isComplete, status.isOK,
              let doc = status.documentNumber, !doc.isEmpty else {
            await MainActor.run {
                errorMessage = Self.failureMessage(status)
                phase = .error
            }
            return
        }

        // Web сервер гарын үсгийг баталгаажуулаад cert subject-оос нэр +
        // иргэний дугаарыг задалж өгсөн. Гэхдээ тэр нэр нь ЛАТИН галиг
        // («ERDENEBAT TSENDDORJ») — иргэн өөрийн нэрийг МОНГОЛООР харах ёстой
        // тул XYP-ийн хураангуйгаас авна.
        //
        // Энэ дуудлагыг амжилтын дэлгэц гарахаас ӨМНӨ хийж байгаа нь санаатай:
        // ингэснээр амжилтын карт, Keychain-ий snapshot, самбар гурвуулаа ЭХНИЙ
        // КАДРААСАА зөв нэртэй байна. Дараа нь засах бол латин нэр хэсэг зуур
        // анивчина. Алдаа гарвал латин нэр дээрээ үлдэнэ — нэвтрэлт зогсохгүй.
        let summary: PersonSummaryResponse? = try? await APIClient.shared
            .request(.dashboard(sessionID: sessionID, pollToken: pollToken))
        let certName = status.name ?? ""
        let name = summary?.mongolianName ?? certName
        let civil = status.idNumber ?? ""
        let level = status.certificateLevel ?? "QUALIFIED"

        await MainActor.run {
            signedInName = name
            signedInNationalId = civil.isEmpty ? typedID : civil
            signedInKycLevel = level
            phase = .success

            let identity = StoredIdentity(
                documentNumber: doc,
                fullName: name,
                civilID: civil,
                nationalID: typedID,
                certificateLevel: level,
                loginAt: ISO8601DateFormatter().string(from: Date())
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                appState.didLogin(identity: identity)
                // Байгууллага/хүүхдийн зөвхөн-унших жагсаалт — pollToken хүчинтэй байхад НЭГ удаа.
                appState.loadPersonExtras(sessionID: sessionID, pollToken: pollToken)
            }
        }
    }

    private static func failureMessage(_ status: StatusResponse) -> String {
        if let err = status.error, !err.isEmpty { return err }
        switch status.endResult ?? "" {
        case "USER_REFUSED", "USER_REFUSED_INTERACTION":
            return "Хэрэглэгч татгалзсан байна."
        case "TIMEOUT":
            return "Хугацаа дууслаа."
        case "":
            return status.isComplete ? "Баталгаажуулалт амжилтгүй." : "Хугацаа дууслаа."
        default:
            return "Баталгаажуулалт амжилтгүй (\(status.endResult ?? ""))."
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task {
            while !Task.isCancelled, countdown > 0, phase == .waiting || mode == .qr {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { countdown = max(countdown - 1, 0) }
            }
        }
    }

    private func cancelWaiting() {
        pollTask?.cancel()
        countdownTask?.cancel()
        phase = .idle
        verificationCode = ""
        if mode == .qr { initQR() }
    }

    // MARK: - QR Code Generation (CoreImage)

    private func generateQRCode(from string: String) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }

        let scale: CGFloat = 10
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

// MARK: - Mode + Phase

private enum LoginTab {
    case nationalID, qr
}

private enum AuthPhase {
    case idle, loading, waiting, success, error
}
