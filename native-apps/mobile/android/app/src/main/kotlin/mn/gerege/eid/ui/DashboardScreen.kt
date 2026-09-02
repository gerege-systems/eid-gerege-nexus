package mn.gerege.eid.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
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

/** Самбар — iOS-ийн `MobileDashboardPage`-тай ижил агуулга, ижил дараалал. */
@Composable
fun DashboardScreen(state: AppState) {
    val c = LocalEidColors.current
    EidScreen(title = stringResource(R.string.Nav_Dashboard)) {
        EidCard {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(
                    initials(state.fullName),
                    fontSize = 20.sp, fontWeight = FontWeight.Bold, color = c.eidAccent,
                    modifier = Modifier
                        .size(56.dp)
                        .background(c.eidAccentSubtle, CircleShape)
                        .wrapContentSize(Alignment.Center),
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(state.fullName.ifEmpty { stringResource(R.string.Dashboard_Greeting) },
                         fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary)
                    if (state.civilId.isNotEmpty()) {
                        Text(state.civilId, fontSize = 12.sp, fontFamily = FontFamily.Monospace, color = c.eidMuted)
                    }
                }
            }
            StatusPill(stringResource(R.string.Dashboard_StatusBadge), PillVariant.OK)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            StatTile(stringResource(R.string.Dashboard_Stats_Logins),
                     state.activity.count { it.sessionType == "AUTH" }.toString(), Modifier.weight(1f))
            StatTile(stringResource(R.string.Nav_MyOrganizations),
                     state.organizations.size.toString(), Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            StatTile(stringResource(R.string.Nav_Children), state.children.size.toString(), Modifier.weight(1f))
            StatTile(stringResource(R.string.Dashboard_Stats_Certificates),
                     if (state.identity?.documentNumber.isNullOrEmpty()) "0" else "1", Modifier.weight(1f))
        }

        EidCard {
            Text(stringResource(R.string.Dashboard_Activity_Section),
                 fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary)
            val recent = state.activity.take(5)
            if (recent.isEmpty()) {
                Text(stringResource(R.string.Dashboard_Activity_Empty), fontSize = 13.sp, color = c.eidMuted)
            } else {
                recent.forEach { entry ->
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(entry.rpName, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = c.textPrimary)
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

@Composable
private fun StatTile(label: String, value: String, modifier: Modifier = Modifier) {
    val c = LocalEidColors.current
    EidCard(modifier = modifier, padding = 14.dp) {
        Text(value, fontSize = 26.sp, fontWeight = FontWeight.SemiBold, color = c.textPrimary)
        Text(label, fontSize = 11.sp, color = c.eidMuted)
    }
}

internal fun initials(name: String): String =
    name.split(" ").filter { it.isNotBlank() }.take(2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("").ifEmpty { "?" }
