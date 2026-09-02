import Foundation

struct NativeSettings: Codable {
    /// Ширээний domain шугам. Хаяг нь ПЛАТФОРМ биш FORM FACTOR-ыг нэрлэнэ:
    /// macOS ба Windows хоёр нэг шугам хуваалцана.
    ///
    /// Web ба API нэг host дээр байгаа нь санаатай: ажлын мужаас гарах дуудлага
    /// same-origin болж, session cookie нь `SameSite=Strict` хэвээр ажиллана.
    /// Бүртгэл: `native-apps/shared/device_lines.json`.
    static let lineOrigin = "https://desktop.eid.gerege.mn"

    var schemaVersion = 1
    var launchAtLogin = false
    var language = "mn"
    var webEndpoint = NativeSettings.lineOrigin
    var apiEndpoint = NativeSettings.lineOrigin
    var printerTransport = "USB"
    var printerHost = ""
    var printerPort = 9100
    var serialPort = ""
    var baudRate = 9600
    var paperWidth = "80 mm"
    var scannerMode = "Keyboard wedge"
    var scannerSuffix = "Enter"
    var biometricLock = true
    var idleLockMinutes = 5
    var updateChannel = "Stable"
    var telemetry = true
    var deviceName = Host.current().localizedName ?? "Mac"
    var site = ""
    var deviceID = ""

    static let storageKey = "mn.gerege.eid.native-settings.v1"
    static func load() -> NativeSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        // Нүүлгэх блок энд байхгүй нь санаатай: энэ суулгацын анхны хувилбар
        // болохоор хадгалагдсан хуучин хаяг гэж байхгүй. `schemaVersion` нь
        // ирээдүйн нүүлгэлтийн бариул болж үлдэнэ.
        return value
    }
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
