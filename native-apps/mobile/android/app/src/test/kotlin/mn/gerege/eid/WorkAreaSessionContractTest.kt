package mn.gerege.eid

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

/**
 * Ажлын мужийн нэвтрэлт нэг мөрөөс хамаарна: серверийн cookie-гийн нэр.
 *
 * Түүнийг Go тал дээр сольвол хаана ч компайлын алдаа гарахгүй — Swift ба
 * Kotlin тал хуучин нэрээ хайсаар байж, клиентүүдийн ажлын муж чимээгүйхэн
 * «нэвтрээгүй» болно. Native тал нэвтэрсэн хэвээр байх тул хүн юу ч буруу
 * болсныг мэдэхгүй: зүгээр л таб нь хоосон.
 *
 * Цөмийн репод энэ тест `csrf.go`-гийн `TenantSessionCookie`-той гурвууланг
 * тулгадаг. ЭНЭ репод цөмийн код байхгүй (`go.mod`-ийн нэг мөр л түүх нь) тул
 * хоёр клиентээ хооронд нь барина — гурав дахь тал нь цөмийн тестийнх.
 */
class WorkAreaSessionContractTest {

    private val repo = File("../../../..")

    private fun read(path: String) = File(repo, path).readText()

    @Test
    fun bothClientsNameTheSameSessionCookie() {
        val swift = Regex("""cookieName\s*=\s*"([^"]+)"""")
            .find(read("native-apps/desktop/macos/Core/Network/WorkAreaSession.swift"))
            ?.groupValues?.get(1)
        val kotlin = Regex("""COOKIE_NAME\s*=\s*"([^"]+)"""")
            .find(read("native-apps/mobile/android/app/src/main/kotlin/mn/gerege/eid/net/WorkAreaSession.kt"))
            ?.groupValues?.get(1)

        assertEquals("WorkAreaSession.swift-ээс cookie нэр олдсонгүй", true, swift != null)
        assertEquals("macOS/iOS ба Android-ийн cookie нэр зөрж байна", swift, kotlin)
    }

    @Test
    fun theWorkAreaLoadsTheSameOriginTheApiCalls() {
        // Cookie нь host-only. WebView өөр хостоос ачаалагдвал session хэзээ ч
        // илгээгдэхгүй бөгөөд алдаа нь 401 биш — зүгээр л «нэвтрээгүй» дэлгэц.
        val screen = read("native-apps/mobile/android/app/src/main/kotlin/mn/gerege/eid/ui/PlatformScreen.kt")
        assertEquals(
            "Ажлын муж AppConfig.baseUrl-ээс ачаалагдах ЁСТОЙ — өөр хаяг session-ыг тасална",
            true,
            screen.contains("loadUrl(AppConfig.baseUrl)"),
        )
    }
}
