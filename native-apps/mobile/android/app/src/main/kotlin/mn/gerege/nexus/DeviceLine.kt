package mn.gerege.nexus

/**
 * Энэ build-ийн domain шугам.
 *
 * Backend цор ганц. Гэхдээ form factor бүр өөрийн host-оор ханддаг, тэр host нь
 * өөрийн `/api/v1`-ээ мөн үйлчилдэг. Ингэснээр webview доторх дуудлага
 * same-origin болж, session cookie нь `SameSite=Strict` хэвээр ажиллаж, CORS
 * preflight огт үүсэхгүй.
 *
 * Бүртгэл: `native-apps/shared/device_lines.json`.
 */
object DeviceLine {
    /**
     * Энэ build-ийн domain шугам. Байрлуулалт дээр DNS, nginx vhost, TLS
     * гэрчилгээ, API-гийн origin allowlist бэлэн байхыг шаардана — kiosk ба
     * pos шугам АСААГҮЙ, `shared/device_lines.json` дээрх `provisioned`-ыг үз.
     */
    val origin: String = when (BuildConfig.FORM_FACTOR) {
        "kiosk" -> "https://kiosk.eid.gerege.mn"
        "pos" -> "https://pos.eid.gerege.mn"
        else -> "https://mobile.eid.gerege.mn"
    }

    /**
     * Ажиллахаа больсон хуучин анхдагчууд. Зөвхөн эдгээрийг зөөнө. Энд
     * зөвхөн эмулятор дээрх dev анхдагч байна: энэ суулгац шинэ тул нүүлгэх
     * хуучин production хаяг байхгүй.
     *
     * `https://eid.gerege.mn` энд ЗОРИУДААР байхгүй: тэр хаяг ижил backend
     * руу очдог тул ажилласаар байгаа бөгөөд түүнийг хүчээр зөөвөл хөтчийн
     * шугамыг санаатай сонгосон суулгацыг булааж авна.
     */
    private val superseded = setOf("http://10.0.2.2:3000", "http://10.0.2.2:8080")

    fun migrate(stored: String?): String =
        if (stored.isNullOrEmpty() || stored in superseded) origin else stored
}
