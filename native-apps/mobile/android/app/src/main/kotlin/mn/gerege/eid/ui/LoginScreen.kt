package mn.gerege.eid.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.automirrored.filled.Launch
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import mn.gerege.eid.AppConfig
import mn.gerege.eid.AppState
import mn.gerege.eid.R
import mn.gerege.eid.net.ApiClient
import mn.gerege.eid.net.AuthStatus
import mn.gerege.eid.net.StoredIdentity
import mn.gerege.eid.ui.components.*
import mn.gerege.eid.ui.theme.LocalGw
import mn.gerege.eid.ui.theme.Radius
import mn.gerege.eid.ui.theme.Space

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
    val gw = LocalGw.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var phase by remember { mutableStateOf("idle") }   // idle | starting | waiting | success
    var register by remember { mutableStateOf("") }
    var verificationCode by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf("") }
    var showRegister by remember { mutableStateOf(false) }
    var job by remember { mutableStateOf<Job?>(null) }
    val registerInteraction = remember { MutableInteractionSource() }
    val registerFocused by registerInteraction.collectIsFocusedAsState()

    val registerTyped = register.trim()
    val registerValid = registerTyped.length >= 8

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
            .background(gw.bg)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = Space.xl, vertical = Space.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        // Богино агуулгыг ГОЛЛУУЛНА: `fillMaxSize` нь доод хязгаарыг харагдах
        // өндөрт барьдаг тул `CenterVertically` ажиллана, гар гарч ирэхэд
        // `verticalScroll` нь агуулгыг гүйлгэнэ. iOS дээрх дүрэмтэй ижил.
        verticalArrangement = Arrangement.spacedBy(Space.xl, Alignment.CenterVertically),
    ) {
        Box(
            modifier = Modifier
                .size(76.dp)
                .background(Brush.linearGradient(listOf(gw.brand, gw.brandDeep)),
                            RoundedCornerShape(22.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Badge, null, tint = Color.White, modifier = Modifier.size(34.dp))
        }
        Text(AppConfig.BRAND_NAME, style = MaterialTheme.typography.headlineLarge, color = gw.fg1)
        Text(stringResource(R.string.Login_Subtitle),
             style = MaterialTheme.typography.bodySmall, color = gw.fg3, textAlign = TextAlign.Center)

        EidCard(spacing = Space.lg) {
            when (phase) {
                "waiting", "starting" -> {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                        CircularProgressIndicator(color = gw.brand, strokeWidth = 2.dp,
                                                  modifier = Modifier.size(28.dp))
                    }
                    Text(
                        stringResource(if (phase == "waiting") R.string.Login_Waiting_Subtitle
                                       else R.string.Login_Initiate_Loading),
                        style = MaterialTheme.typography.bodySmall, color = gw.fg2,
                        textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                    )
                    if (verificationCode.isNotEmpty()) {
                        BrandSectionLabel(stringResource(R.string.Login_VerificationCode),
                                          Modifier.align(Alignment.CenterHorizontally))
                        BrandCodeRow(verificationCode, Modifier.align(Alignment.CenterHorizontally))
                    }
                    BrandLinkButton(stringResource(R.string.Login_Cancel),
                                    Modifier.align(Alignment.CenterHorizontally)) {
                        job?.cancel(); phase = "idle"
                    }
                }

                "success" -> Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Space.sm, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Verified, null, tint = gw.credit, modifier = Modifier.size(22.dp))
                    Text(stringResource(R.string.Login_Success_Title),
                         style = MaterialTheme.typography.titleMedium, color = gw.fg1)
                }

                else -> {
                    BrandInfoBanner(stringResource(R.string.Login_AppToApp_Hint))

                    LoadingPrimaryButton(
                        label = stringResource(R.string.Login_AppToApp),
                        leadingIcon = Icons.AutoMirrored.Filled.Launch,
                    ) {
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
                        BrandSectionLabel(stringResource(R.string.Login_NationalId))
                        BrandInputCard(
                            leadingIcon = Icons.Filled.Badge,
                            // Хоосон талбар дээр улаан ✗ анивчуулах нь бичиж
                            // эхлээгүй хүнийг буруутгаж байгаа хэрэг.
                            validation = if (registerTyped.isEmpty()) null else BrandValidationState(
                                label = stringResource(
                                    if (registerValid) R.string.Common_Valid else R.string.Common_TooShort),
                                valid = registerValid,
                            ),
                            isFocused = registerFocused,
                        ) {
                            BasicTextField(
                                value = register,
                                onValueChange = { register = it.uppercase() },
                                singleLine = true,
                                interactionSource = registerInteraction,
                                keyboardOptions = KeyboardOptions(
                                    capitalization = KeyboardCapitalization.Characters),
                                textStyle = LocalTextStyle.current.copy(
                                    fontFamily = FontFamily.Monospace, color = gw.fg1),
                                cursorBrush = SolidColor(gw.brand),
                                modifier = Modifier.fillMaxWidth(),
                                decorationBox = { inner ->
                                    if (register.isEmpty()) {
                                        Text(stringResource(R.string.Login_NationalId_Placeholder),
                                             style = MaterialTheme.typography.bodyMedium.copy(
                                                 fontFamily = FontFamily.Monospace),
                                             color = gw.fg4)
                                    }
                                    inner()
                                },
                            )
                        }
                        SecondaryButton(stringResource(R.string.Login_Push),
                                        enabled = registerValid, tone = gw.brand) {
                            run {
                                val session = ApiClient.loginNotify(registerTyped)
                                verificationCode = session.vc.orEmpty()
                                Triple(session.sessionId, session.pollToken, registerTyped)
                            }
                        }
                    } else {
                        BrandLinkButton(stringResource(R.string.Login_OtherDevice),
                                        Modifier.align(Alignment.CenterHorizontally)) {
                            showRegister = true
                        }
                    }
                }
            }
        }

        if (errorMessage.isNotEmpty()) InlineBanner(errorMessage)

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Space.sm),
        ) {
            BrandSecurityFooter(stringResource(R.string.Login_SecurityFooter))
            Text("${AppConfig.host}  ·  ${AppConfig.BRAND_NAME} v1.0.0",
                 style = MaterialTheme.typography.labelSmall.copy(
                     fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Normal),
                 color = gw.fg4)
        }
    }
}
