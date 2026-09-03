package mn.gerege.eid

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * App2App-ийн буцах хаяг нь ДӨРВӨН газарт тохирсон байх ёстой:
 *
 *   1. `AppConfig.APP_TO_APP_CALLBACK` — сервер рүү илгээх утга
 *   2. `AndroidManifest.xml`-ийн intent-filter — OS энэ аппыг сэрээх нөхцөл
 *   3. Платформ backend-ийн `EID_APP_CALLBACKS` — бүтэн URI
 *   4. eID Mongolia RP-ийн `callback_hosts` — зөвхөн `gerege-eid://` scheme
 *
 * Эхний хоёр нь зөрвөл ЮУ Ч алдаа өгөхгүй: eID апп зөв хаягаар буцаах гэж
 * оролдоод OS «ийм зүйл нээх апп алга» гэж чимээгүй хаяна, хүн eID апп дотроо
 * үлдэнэ. Тиймээс эхний хоёрын таарлыг ЭНД барина. Сүүлийн хоёрыг deployment
 * ба eID admin тус тус мэднэ — энэ unit test тэдгээрийг уншиж чадахгүй.
 */
class CallbackContractTest {

    @Test
    fun manifestDeclaresTheCallbackScheme() {
        val uri = AppConfig.APP_TO_APP_CALLBACK          // "gerege-eid://auth"
        val scheme = uri.substringBefore("://")
        val host = uri.substringAfter("://").substringBefore('/')

        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertTrue(
            "AndroidManifest-д $uri-ийн intent-filter алга — eID апп буцаахад OS энэ аппыг олохгүй",
            manifest.contains("""android:scheme="$scheme"""") &&
                manifest.contains("""android:host="$host""""),
        )
    }

    @Test
    fun eidAppSchemesAreQueryable() {
        // Android 11+ дээр `<queries>` блокгүй бол `resolveActivity` нь eID аппыг
        // ОЛОХГҮЙ бөгөөд нэвтрэлт «апп суугаагүй» гэсэн буруу мөрөөр явна.
        val manifest = File("src/main/AndroidManifest.xml").readText()
        val queries = manifest.substringAfter("<queries>", "").substringBefore("</queries>")
        listOf("geregesmartid", "eidmongolia").forEach { scheme ->
            assertTrue("<queries> дотор $scheme схем алга", queries.contains("""android:scheme="$scheme""""))
        }
    }
}
