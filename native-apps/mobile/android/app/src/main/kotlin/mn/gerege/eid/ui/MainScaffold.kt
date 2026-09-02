package mn.gerege.eid.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import mn.gerege.eid.AppState
import mn.gerege.eid.R
import mn.gerege.eid.ui.theme.LocalEidColors

/**
 * Нэвтэрсэн үеийн бүрхүүл — iOS-ийн `MainTabView`-тэй ижил дөрвөн зам.
 *
 * Ширээн дээр эдгээр нь хажуугийн цэсний мөр; гар дээр доод зурвас. Нэр нь
 * ижил `Nav_*` түлхүүрээс ирнэ — гурван клиент нэг зүйлийг нэг нэрээр дуудна.
 */
private enum class Tab(val labelRes: Int, val icon: ImageVector) {
    DASHBOARD(R.string.Nav_Dashboard, Icons.Filled.Home),
    ID(R.string.Nav_MyId, Icons.Filled.Badge),
    LOGS(R.string.Nav_Logs, Icons.Filled.History),
    SETTINGS(R.string.Nav_Settings, Icons.Filled.Settings),
}

@Composable
fun MainScaffold(state: AppState) {
    val c = LocalEidColors.current
    var tab by remember { mutableStateOf(Tab.DASHBOARD) }

    Scaffold(
        containerColor = c.eidSurface,
        bottomBar = {
            NavigationBar(containerColor = c.eidCardBackground) {
                Tab.entries.forEach { entry ->
                    NavigationBarItem(
                        selected = tab == entry,
                        onClick = { tab = entry },
                        icon = { Icon(entry.icon, contentDescription = null) },
                        label = { Text(stringResource(entry.labelRes)) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = c.eidAccent,
                            selectedTextColor = c.eidAccent,
                            indicatorColor = c.eidAccentSubtle,
                            unselectedIconColor = c.eidMuted,
                            unselectedTextColor = c.eidMuted,
                        ),
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                Tab.DASHBOARD -> DashboardScreen(state)
                Tab.ID -> IdScreen(state)
                Tab.LOGS -> LogsScreen(state)
                Tab.SETTINGS -> SettingsScreen(state)
            }
        }
    }
}
