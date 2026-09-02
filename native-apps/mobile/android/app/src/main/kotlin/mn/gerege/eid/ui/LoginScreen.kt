package mn.gerege.eid.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import mn.gerege.eid.AppConfig
import mn.gerege.eid.AppState
import mn.gerege.eid.R
import mn.gerege.eid.net.ApiClient
import mn.gerege.eid.net.AuthStatus
import mn.gerege.eid.net.StoredIdentity
import mn.gerege.eid.ui.components.*
import mn.gerege.eid.ui.theme.LocalEidColors

/**
 * Нэвтрэх дэлгэц — iOS-ийн `MobileLoginView`-тэй ЯГ ижил урсгал.
 *
 * Мак дээр QR/РД push-ыг ХӨРШ утас зөвшөөрдөг. Утсан дээр тэр зөвшөөрөгч нь
 * өөрөө байгаа тул session-ийг **app-to-app**-аар eID Mongolia апп руу
 * шилжүүлнэ: `geregesmartid://approve?sessionId=...`. Шинэ backend endpoint
 * нэмээгүй — session нь хэн зөвшөөрснөөс үл хамааран ижил.
 */
@Composable
fun LoginScreen(state: AppState) {
    val c = LocalEidColors.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var phase by remember { mutableStateOf("idle") }   // idle | starting | waiting | success
    var register by remember { mutableStateOf("") }
    var verificationCode by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var showRegister by remember { mutableStateOf(false) }
    var job by remember { mutableStateOf<Job?>(null) }

    // eID апп суусан эсэх. `<queries>` блокгүй бол Android 11+ дээр үргэлж
    // null буцаана — тэр тохиолдолд РД push зам нээлттэй тул апп гацахгүй.
    fun eidAppIntent(sessionId: String): Intent? =
        listOf("geregesmartid", "eidmongolia").firstNotNullOfOrNull { scheme ->
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$scheme://approve?sessionId=$sessionId"))
            if (intent.resolveActivity(context.packageManager) != null) intent else null
        }

    fun finish(status: AuthStatus, sessionId: String, pollToken: String, typedId: String) {
        if (!status.isComplete || !status.isOk || status.documentNumber.isNullOrEmpty()) {
            errorMessage = status.error ?: context.getString(R.string.Login_Error_Failed)
            phase = "idle"
            return
        }
        scope.launch {
            // Гэрчилгээний нэр нь ЛАТИН галиг — иргэн өөрийн нэрийг МОНГОЛООР
            // харах ёстой тул XYP-ийн хураангуйгаас авна (ширээ, iOS-тэй ижил).
            val mongolian = runCatching { ApiClient.personSummary(sessionId, pollToken).mongolianName }.getOrNull()
            val identity = StoredIdentity(
                documentNumber = status.documentNumber,
                fullName = mongolian ?: status.name.orEmpty(),
                civilId = status.idNumber.orEmpty(),
                nationalId = typedId,
                certificateLevel = status.certificateLevel ?: "QUALIFIED",
                loginAt = AppState.isoNow(),
            )
            phase = "success"
            state.didLogin(identity, sessionId, pollToken)
        }
    }

    fun run(start: suspend () -> Triple<String, String, String>) {
        job?.cancel()
        errorMessage = ""
        phase = "starting"
        job = scope.launch {
            runCatching {
                val (sessionId, pollToken, typedId) = start()
                phase = "waiting"
                val status = ApiClient.waitForAuth(sessionId, pollToken)
                finish(status, sessionId, pollToken, typedId)
            }.onFailure {
                errorMessage = it.message ?: context.getString(R.string.Login_Error_Failed)
                phase = "idle"
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(c.eidSurface)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        // Богино агуулгыг ГОЛЛУУЛНА: `fillMaxSize` нь доод хязгаарыг харагдах
        // өндөрт барьдаг тул `CenterVertically` ажиллана, гар гарч ирэхэд
        // `verticalScroll` нь агуулгыг гүйлгэнэ. iOS дээрх дүрэмтэй ижил.
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        Text(
            "eID",
            fontSize = 30.sp,
            fontWeight = FontWeight.Bold,
            color = c.eidAccent,
            modifier = Modifier
                .background(c.eidAccentSubtle, RoundedCornerShape(22.dp))
                .padding(horizontal = 22.dp, vertical = 16.dp),
        )
        Text(AppConfig.BRAND_NAME, fontSize = 28.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
        Text(stringResource(R.string.Login_Subtitle), fontSize = 13.sp, color = c.eidMuted)

        EidCard {
            when (phase) {
                "waiting", "starting" -> {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                    ) { CircularProgressIndicator(color = c.eidAccent, strokeWidth = 2.dp) }
                    Text(
                        stringResource(if (phase == "waiting") R.string.Login_Waiting_Subtitle else R.string.Login_Initiate_Loading),
                        fontSize = 13.sp, color = c.eidMuted, modifier = Modifier.fillMaxWidth(),
                    )
                    if (verificationCode.isNotEmpty()) {
                        Text(stringResource(R.string.Login_VerificationCode), fontSize = 11.sp,
                             fontWeight = FontWeight.SemiBold, color = c.eidMuted)
                        Text(verificationCode, fontSize = 26.sp, fontWeight = FontWeight.Bold,
                             fontFamily = FontFamily.Monospace, color = c.eidAccentStrong)
                    }
                    SecondaryButton(stringResource(R.string.Login_Cancel)) {
                        job?.cancel(); phase = "idle"
                    }
                }
                "success" -> Text(stringResource(R.string.Login_Success_Title),
                                  fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = c.eidSuccess)
                else -> {
                    PrimaryButton(stringResource(R.string.Login_AppToApp)) {
                        run {
                            val session = ApiClient.start()
                            verificationCode = session.vc.orEmpty()
                            val intent = eidAppIntent(session.sessionId)
                            if (intent == null) {
                                showRegister = true
                                errorMessage = context.getString(R.string.Login_Error_AppMissing)
                            } else {
                                context.startActivity(intent)
                            }
                            Triple(session.sessionId, session.pollToken, "")
                        }
                    }
                    if (showRegister) {
                        OutlinedTextField(
                            value = register,
                            onValueChange = { register = it.uppercase() },
                            label = { Text(stringResource(R.string.Login_NationalId)) },
                            placeholder = { Text(stringResource(R.string.Login_NationalId_Placeholder)) },
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        SecondaryButton(stringResource(R.string.Login_Push), enabled = register.trim().length >= 8) {
                            run {
                                val session = ApiClient.loginNotify(register.trim())
                                verificationCode = session.vc.orEmpty()
                                Triple(session.sessionId, session.pollToken, register.trim())
                            }
                        }
                    } else {
                        TextButton(onClick = { showRegister = true }) {
                            Text(stringResource(R.string.Login_OtherDevice), color = c.eidAccent, fontSize = 13.sp)
                        }
                    }
                }
            }
        }

        if (errorMessage.isNotEmpty()) InlineBanner(errorMessage)

        Text("${AppConfig.host}  ·  ${AppConfig.BRAND_NAME} v1.0.0",
             fontSize = 10.sp, fontFamily = FontFamily.Monospace, color = c.eidMuted)
    }
}
