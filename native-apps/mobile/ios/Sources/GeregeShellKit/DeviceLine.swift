import Foundation

/// iOS/iPadOS-ийн domain шугам.
///
/// Backend цор ганц. Гэхдээ төхөөрөмж бүр өөрийн host-оор ханддаг, тэр host нь
/// өөрийн `/api/v1`-ээ мөн үйлчилдэг. Ингэснээр webview доторх дуудлага
/// same-origin болж, session cookie нь `SameSite=Strict` хэвээр ажиллаж, CORS
/// preflight огт үүсэхгүй.
///
/// Бүртгэл: `native-apps/shared/device_lines.json`.
public enum GeregeDeviceLine {
    /// Гарын шугам. Байрлуулалт дээр DNS, nginx vhost, TLS гэрчилгээ,
    /// API-гийн origin allowlist дөрвүүлэн бэлэн байхыг шаардана.
    public static let origin = "https://mobile.eid.gerege.mn"

    /// Ажиллахаа больсон хуучин анхдагчууд. Зөвхөн эдгээрийг зөөнө.
    ///
    /// Энд зөвхөн dev-ийн анхдагч байгаа: энэ суулгац шинэ тул нүүлгэх
    /// хуучин production хаяг байхгүй. `https://eid.gerege.mn` энд ЗОРИУДААР
    /// байхгүй — тэр хаяг ижил backend руу очдог тул ажилласаар байгаа бөгөөд
    /// түүнийг хүчээр зөөвөл хөтчийн шугамыг санаатай сонгосон суулгацыг
    /// булааж авна.
    public static let supersededOrigins = ["http://localhost:8080"]

    /// Хадгалагдсан утгыг шаардлагатай бол зөөж, эцсийн утгыг буцаана.
    public static func migrate(_ stored: String?) -> String {
        guard let stored, !stored.isEmpty else { return origin }
        return supersededOrigins.contains(stored) ? origin : stored
    }
}
