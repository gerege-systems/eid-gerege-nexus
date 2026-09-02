package mn.gerege.eid.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mn.gerege.eid.ui.theme.LocalEidColors

/**
 * Ширээний `Design/Styles.swift`-ийн дүрсүүдийн Compose дүйцэл.
 *
 * Нэр, радиус, зай, өнгө нь ижил — хоёр платформын дэлгэц зэрэгцүүлж харахад
 * нэг апп шиг харагдах ёстой. Өнгө нь үүсгэсэн токенуудаас (`EidColors`).
 */

@Composable
fun EidCard(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    val c = LocalEidColors.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(c.eidCardBackground, RoundedCornerShape(14.dp))
            .border(1.dp, c.eidCardStroke, RoundedCornerShape(14.dp))
            .padding(padding),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content,
    )
}

enum class PillVariant { OK, WARN, ACCENT }

@Composable
fun StatusPill(text: String, variant: PillVariant = PillVariant.OK) {
    val c = LocalEidColors.current
    val color = when (variant) {
        PillVariant.OK -> c.eidSuccess
        PillVariant.WARN -> c.eidWarning
        PillVariant.ACCENT -> c.eidAccent
    }
    Text(
        text = text,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = color,
        modifier = Modifier
            .background(color.copy(alpha = 0.12f), RoundedCornerShape(20.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

/** Шошго + утга. iOS-ийн `MobileField`-тэй ижил хэмжээс. */
@Composable
fun EidField(label: String, value: String, mono: Boolean = false) {
    val c = LocalEidColors.current
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(label.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Medium, color = c.eidMuted)
        Text(
            value.ifEmpty { "—" },
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = c.textPrimary,
            fontFamily = if (mono) FontFamily.Monospace else FontFamily.Default,
        )
    }
}

@Composable
fun InlineBanner(text: String, isError: Boolean = true) {
    val c = LocalEidColors.current
    val tint = if (isError) c.eidDanger else c.eidAccent
    Text(
        text = text,
        fontSize = 12.sp,
        color = tint,
        modifier = Modifier
            .fillMaxWidth()
            .background(tint.copy(alpha = 0.10f), RoundedCornerShape(10.dp))
            .padding(12.dp),
    )
}

@Composable
fun PrimaryButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    val c = LocalEidColors.current
    Button(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(10.dp),
        colors = ButtonDefaults.buttonColors(containerColor = c.eidAccent, contentColor = Color.White),
        modifier = Modifier.fillMaxWidth().height(48.dp),
    ) { Text(text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold) }
}

@Composable
fun SecondaryButton(text: String, enabled: Boolean = true, onClick: () -> Unit) {
    val c = LocalEidColors.current
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(10.dp),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = c.eidAccent),
        modifier = Modifier.fillMaxWidth().height(44.dp),
    ) { Text(text, fontSize = 14.sp, fontWeight = FontWeight.Medium) }
}

/** Дэлгэц бүрийн нийтлэг хүрээ — гарчиг + гүйлгэх муж. */
@Composable
fun EidScreen(title: String, subtitle: String? = null, content: @Composable ColumnScope.() -> Unit) {
    val c = LocalEidColors.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(c.eidSurface)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = c.textPrimary)
        if (!subtitle.isNullOrEmpty()) {
            Text(subtitle, fontSize = 12.sp, color = c.eidMuted)
        }
        content()
        Spacer(Modifier.height(8.dp))
    }
}
