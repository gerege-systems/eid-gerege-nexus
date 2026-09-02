package mn.gerege.eid.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import mn.gerege.eid.AppConfig
import mn.gerege.eid.AppState
import mn.gerege.eid.R
import mn.gerege.eid.ui.components.*
import mn.gerege.eid.ui.theme.LocalEidColors

/**
 * Тохиргоо — iOS-ийн `MobileSettingsPage`-тай ижил хүрээ.
 *
 * Хэлийг Android дээр СИСТЕМ шийднэ (`res/values-*`): аппын дотор хэлний
 * сонголт тавихгүй байгаа нь ялгаа биш, платформын зөв зан. iOS дээр
 * ширээнээс өвлөсөн `LocalizationService` нь өөрөө хэл сольдог.
 */
@Composable
fun SettingsScreen(state: AppState) {
    val c = LocalEidColors.current
    var server by remember { mutableStateOf(AppConfig.prefs().getString(AppConfig.BASE_URL_KEY, "").orEmpty()) }

    EidScreen(title = stringResource(R.string.Nav_Settings)) {
        EidCard {
            Text(stringResource(R.string.Settings_Server), fontSize = 14.sp,
                 fontWeight = FontWeight.SemiBold, color = c.textPrimary)
            OutlinedTextField(
                value = server,
                onValueChange = { server = it; AppConfig.baseUrl = it },
                placeholder = { Text(AppConfig.DEFAULT_BASE_URL) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(AppConfig.DEFAULT_BASE_URL, fontSize = 11.sp, color = c.eidMuted)
        }
        EidCard {
            Text(stringResource(R.string.Settings_About), fontSize = 14.sp,
                 fontWeight = FontWeight.SemiBold, color = c.textPrimary)
            EidField(stringResource(R.string.App_VersionLabel), "${AppConfig.BRAND_NAME} v1.0.0", mono = true)
            EidField(stringResource(R.string.Settings_Host), AppConfig.host, mono = true)
        }
        SecondaryButton(stringResource(R.string.Nav_Logout)) { state.logout() }
    }
}
