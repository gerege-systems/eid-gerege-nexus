package mn.gerege.eid.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mn.gerege.eid.AppState
import mn.gerege.eid.R
import mn.gerege.eid.ui.components.*
import mn.gerege.eid.ui.theme.LocalEidColors

/**
 * Лог түүх — ЭНЭ төхөөрөмжийн локал бүртгэл.
 *
 * v3 RP-API нь иргэний бүх session-ий түүхийг өгдөггүй тул утас, мак хоёр
 * өөр өөр жагсаалт харуулна — тэр нь алдаа биш, өөр өөр төхөөрөмжийн түүх.
 */
@Composable
fun LogsScreen(state: AppState) {
    val c = LocalEidColors.current
    EidScreen(title = stringResource(R.string.Nav_Logs), subtitle = stringResource(R.string.Logs_Subtitle)) {
        if (state.activity.isEmpty()) {
            EidCard { Text(stringResource(R.string.Dashboard_Activity_Empty), fontSize = 13.sp, color = c.eidMuted) }
        } else {
            state.activity.forEach { entry ->
                EidCard(padding = 14.dp) {
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(
                                stringResource(if (entry.sessionType == "AUTH") R.string.Dashboard_Activity_Auth
                                               else R.string.Dashboard_Activity_Sign),
                                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary,
                            )
                            Text(entry.rpName, fontSize = 12.sp, color = c.eidMuted)
                            Text(AppState.shortDate(entry.createdAt), fontSize = 11.sp,
                                 fontFamily = FontFamily.Monospace, color = c.eidMuted)
                        }
                        StatusPill(
                            stringResource(if (entry.result == "OK") R.string.Dashboard_Activity_Success
                                           else R.string.Dashboard_Activity_Failure),
                            if (entry.result == "OK") PillVariant.OK else PillVariant.WARN,
                        )
                    }
                }
            }
        }
    }
}
