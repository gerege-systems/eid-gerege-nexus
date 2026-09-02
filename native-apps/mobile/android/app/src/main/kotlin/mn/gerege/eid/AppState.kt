package mn.gerege.eid

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import mn.gerege.eid.net.ActivityEntry
import mn.gerege.eid.net.ApiClient
import mn.gerege.eid.net.Child
import mn.gerege.eid.net.Organization
import mn.gerege.eid.net.StoredIdentity
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Аппын төлөв — ширээний `AppState.swift`-ийн Android дүйцэл.
 *
 * Хоёр л дэлгэц: нэвтрэлт эсвэл самбар. Тэр нь Keychain/Keystore дэх snapshot
 * байгаа эсэхээр шийдэгдэнэ — сүлжээ шаардахгүй тул нислэгийн горимд ч апп
 * нээгдэнэ, зөвхөн шинэ өгөгдөл татагдахгүй.
 */
class AppState(application: Application) : AndroidViewModel(application) {
    enum class Screen { LOGIN, DASHBOARD }

    private val store = IdentityStore(application)

    var screen by mutableStateOf(if (store.load() != null) Screen.DASHBOARD else Screen.LOGIN)
        private set
    var identity by mutableStateOf(store.load())
        private set

    val organizations = mutableStateListOf<Organization>()
    val children = mutableStateListOf<Child>()
    var activity by mutableStateOf(store.activity())
        private set

    val fullName: String get() = identity?.fullName.orEmpty()
    val civilId: String get() = identity?.civilId.orEmpty()

    fun didLogin(identity: StoredIdentity, sessionId: String, pollToken: String) {
        store.save(identity)
        this.identity = identity
        screen = Screen.DASHBOARD
        logActivity("AUTH", "OK")
        loadPersonExtras(sessionId, pollToken)
    }

    fun logout() {
        store.clear()
        identity = null
        organizations.clear()
        children.clear()
        activity = emptyList()
        screen = Screen.LOGIN
    }

    /**
     * Байгууллага/хүүхдийн ЗӨВХӨН УНШИХ жагсаалт. pollToken нь 10 минут
     * хүчинтэй тул нэвтэрсэн даруйд НЭГ удаа татна — ширээнийхтэй ижил дүрэм.
     */
    private fun loadPersonExtras(sessionId: String, pollToken: String) {
        viewModelScope.launch {
            runCatching { ApiClient.organizations(sessionId, pollToken) }
                .onSuccess { organizations.clear(); organizations.addAll(it) }
            runCatching { ApiClient.children(sessionId, pollToken) }
                .onSuccess { children.clear(); children.addAll(it) }
        }
    }

    fun logActivity(type: String, result: String) {
        val entry = ActivityEntry(
            id = System.currentTimeMillis().toString(),
            sessionType = type,
            result = result,
            rpName = AppConfig.BRAND_NAME,
            createdAt = isoNow(),
        )
        store.appendActivity(entry)
        activity = store.activity()
    }

    companion object {
        fun isoNow(): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            .apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())

        /** ISO мөрийг «2026.09.02 17:41» болгоно. Задлагдахгүй бол хэвээр нь. */
        fun shortDate(iso: String): String = runCatching {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                .apply { timeZone = TimeZone.getTimeZone("UTC") }
            val date = parser.parse(iso.take(19)) ?: return iso
            SimpleDateFormat("yyyy.MM.dd HH:mm", Locale.US).format(date)
        }.getOrDefault(iso)
    }
}
