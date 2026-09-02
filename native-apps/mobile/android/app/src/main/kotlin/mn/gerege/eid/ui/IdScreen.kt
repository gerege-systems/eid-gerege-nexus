package mn.gerege.eid.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.HorizontalDivider
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

/** Миний ID — iOS-ийн `MobileIdPage`-тай ижил талбарууд, ижил дараалал. */
@Composable
fun IdScreen(state: AppState) {
    val c = LocalEidColors.current
    val identity = state.identity
    EidScreen(title = stringResource(R.string.Nav_MyId), subtitle = stringResource(R.string.Id_Subtitle)) {
        if (identity == null) {
            EidCard { Text(stringResource(R.string.Dashboard_Activity_Empty), fontSize = 13.sp, color = c.eidMuted) }
            return@EidScreen
        }
        EidCard {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(identity.fullName.ifEmpty { "—" }, fontSize = 18.sp,
                     fontWeight = FontWeight.Bold, color = c.textPrimary, modifier = Modifier.weight(1f))
                StatusPill(stringResource(R.string.Common_Active), PillVariant.OK)
            }
            HorizontalDivider(color = c.eidCardStroke)
            EidField(stringResource(R.string.Id_RegNumber), identity.nationalId, mono = true)
            if (identity.civilId.isNotEmpty()) {
                EidField(stringResource(R.string.Id_CivilId), identity.civilId, mono = true)
            }
        }
        EidCard {
            EidField(stringResource(R.string.Id_Level), identity.certificateLevel)
            EidField(stringResource(R.string.Id_DocNumber), identity.documentNumber, mono = true)
        }
        if (state.organizations.isNotEmpty()) {
            EidCard {
                Text(stringResource(R.string.Nav_MyOrganizations), fontSize = 14.sp,
                     fontWeight = FontWeight.SemiBold, color = c.textPrimary)
                state.organizations.forEach { org ->
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.weight(1f)) {
                            Text(org.orgName, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = c.textPrimary)
                            Text(org.orgRegister, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = c.eidMuted)
                        }
                        StatusPill(org.rightType, PillVariant.ACCENT)
                    }
                }
                Text(stringResource(R.string.Read_Only_Hint), fontSize = 11.sp, color = c.eidMuted)
            }
        }
        if (state.children.isNotEmpty()) {
            EidCard {
                Text(stringResource(R.string.Nav_Children), fontSize = 14.sp,
                     fontWeight = FontWeight.SemiBold, color = c.textPrimary)
                state.children.forEach { child ->
                    Row(verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.weight(1f)) {
                            Text(child.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = c.textPrimary)
                            Text(child.regNo, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = c.eidMuted)
                        }
                        StatusPill(
                            stringResource(if (child.registered) R.string.Common_Registered else R.string.Common_Pending),
                            if (child.registered) PillVariant.OK else PillVariant.WARN,
                        )
                    }
                }
                Text(stringResource(R.string.Read_Only_Hint), fontSize = 11.sp, color = c.eidMuted)
            }
        }
    }
}
