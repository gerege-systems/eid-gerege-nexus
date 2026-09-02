package mn.gerege.eid.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import mn.gerege.eid.AppConfig
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Web backend-ийн нийтийн `/api/…` route-ууд — ширээний `APIClient.swift`-ийн дүйцэл.
 *
 * JSON-ыг `org.json`-оор уншиж байгаа нь санаатай: талбарууд цөөхөн бөгөөд
 * serialization plugin нэмэх нь энэ хэмжээний ачаанд илүүц.
 */
object ApiClient {
    class ApiException(message: String) : Exception(message)

    private val json = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        // `/api/status` нь long poll — сервер тал хүсэлтийг ~1 секунд барина.
        .callTimeout(90, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .build()

    private suspend fun call(path: String, body: JSONObject?): JSONObject = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(AppConfig.baseUrl + path)
            // `X-Eid-Client` header БАЙХГҮЙ: платформ дээр RP нэг бөгөөд энэ апп
            // түүний өөрийн клиент (`rpclient.ts § RP_SELF`). Header нь юуг ч
            // сонгодоггүй болсон тул илгээх нь худал баримт үлдээхтэй адил.
            .apply { if (body != null) post(body.toString().toRequestBody(json)) else get() }
            .build()
        client.newCall(request).execute().use { response ->
            val text = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                val message = runCatching { JSONObject(text).optString("error") }.getOrNull()
                throw ApiException(message?.takeIf { it.isNotEmpty() } ?: "HTTP ${response.code}")
            }
            if (text.isEmpty()) JSONObject() else JSONObject(text)
        }
    }

    /**
     * `POST /api/start` — anonymous device-link session (app-to-app-д ашиглана).
     *
     * `callbackUrl` нь eID апп зөвшөөрсний дараа БУЦАХ хаяг. Сервер тал үүнийг
     * RP-ийн `callback_hosts` allowlist-аар шалгана — бүртгэгдээгүй бол чимээгүй
     * хаягдаж, зөвшөөрсний дараа хүн eID апп дотроо үлдэнэ.
     */
    suspend fun start(): StartSession =
        call("/api/start", JSONObject().put("callbackUrl", AppConfig.APP_TO_APP_CALLBACK)).let {
        StartSession(it.getString("sessionId"), it.optString("vc").ifEmpty { null }, it.optString("pollToken"))
    }

    /** `POST /api/login-notify` — регистрээр утас руу push (өөр төхөөрөмж дээр зөвшөөрөх). */
    suspend fun loginNotify(register: String): StartSession =
        call("/api/login-notify", JSONObject().put("register", register)).let {
            StartSession(it.getString("sessionId"), it.optString("vc").ifEmpty { null }, it.optString("pollToken"))
        }

    private suspend fun status(sessionId: String, pollToken: String): AuthStatus =
        call("/api/status?sessionId=$sessionId&pollToken=$pollToken", null).let {
            AuthStatus(
                state = it.optString("state").ifEmpty { null },
                endResult = it.optString("endResult").ifEmpty { null },
                documentNumber = it.optString("documentNumber").ifEmpty { null },
                certificateLevel = it.optString("certificateLevel").ifEmpty { null },
                name = it.optString("name").ifEmpty { null },
                idNumber = it.optString("idNumber").ifEmpty { null },
                error = it.optString("error").ifEmpty { null },
            )
        }

    /**
     * COMPLETE болтол poll хийнэ — ширээний `waitForAuth`-тай ижил хэмнэл
     * (400мс, 5 минутын хязгаар). Cancel хийхэд coroutine нь өөрөө зогсоно.
     */
    suspend fun waitForAuth(sessionId: String, pollToken: String, timeoutMs: Long = 300_000): AuthStatus {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val status = status(sessionId, pollToken)
            status.error?.let { throw ApiException(it) }
            if (status.isComplete) return status
            delay(400)
        }
        throw ApiException("timeout")
    }

    /** `POST /api/dashboard` — монгол нэрийн эх сурвалж. */
    suspend fun personSummary(sessionId: String, pollToken: String): PersonSummary =
        call("/api/dashboard", sessionBody(sessionId, pollToken)).let {
            PersonSummary(
                it.optString("firstName").ifEmpty { null },
                it.optString("lastName").ifEmpty { null },
                it.optString("familyName").ifEmpty { null },
            )
        }

    /** `POST /api/representations` — төлөөлж чадах байгууллагууд (ЗӨВХӨН УНШИХ). */
    suspend fun organizations(sessionId: String, pollToken: String): List<Organization> {
        val array = call("/api/representations", sessionBody(sessionId, pollToken)).optJSONArray("representations")
            ?: return emptyList()
        return (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            Organization(item.optString("orgRegister"), item.optString("orgName"), item.optString("rightType"))
        }
    }

    /** `POST /api/children` — асран хамгаалж буй хүүхдүүд (ЗӨВХӨН УНШИХ). */
    suspend fun children(sessionId: String, pollToken: String): List<Child> {
        val array = call("/api/children", sessionBody(sessionId, pollToken)).optJSONArray("children")
            ?: return emptyList()
        return (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            Child(item.optString("regNo"), item.optString("name"), item.optBoolean("registered"))
        }
    }

    private fun sessionBody(sessionId: String, pollToken: String) =
        JSONObject().put("sessionId", sessionId).put("pollToken", pollToken)
}
