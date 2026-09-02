package mn.gerege.eid.net

/** `/api/start`, `/api/login-notify` — session эхлэх хариу. */
data class StartSession(val sessionId: String, val vc: String?, val pollToken: String)

/** `/api/status` — session-ий төлөв (ширээний `StatusResponse`-той ижил талбарууд). */
data class AuthStatus(
    val state: String?,
    val endResult: String?,
    val documentNumber: String?,
    val certificateLevel: String?,
    val name: String?,
    val idNumber: String?,
    val error: String?,
) {
    val isComplete get() = state == "COMPLETE"
    val isOk get() = endResult == "OK"
}

/**
 * `/api/dashboard` — XYP-ийн хүний хураангуй.
 *
 * Гэрчилгээний subject дэх нэр нь ЛАТИН галиг тул дэлгэцэнд харагдах нэрийг
 * эндээс авна — ширээ, iOS хоёрын дүрэмтэй ижил.
 */
data class PersonSummary(val firstName: String?, val lastName: String?, val familyName: String?) {
    val mongolianName: String?
        get() = listOfNotNull(lastName, firstName)
            .map { it.trim() }.filter { it.isNotEmpty() }
            .takeIf { it.isNotEmpty() }?.joinToString(" ")
}

data class Organization(val orgRegister: String, val orgName: String, val rightType: String)
data class Child(val regNo: String, val name: String, val registered: Boolean)

/** Нэвтэрсэн иргэний snapshot — Keystore-оор шифрлэгдэж хадгалагдана. */
data class StoredIdentity(
    val documentNumber: String,
    val fullName: String,
    val civilId: String,
    val nationalId: String,
    val certificateLevel: String,
    val loginAt: String,
)

/** Энэ ТӨХӨӨРӨМЖ дээрх үйлдлийн локал бүртгэл (v3-д серверийн түүх байхгүй). */
data class ActivityEntry(
    val id: String,
    val sessionType: String,
    val result: String,
    val rpName: String,
    val createdAt: String,
)
