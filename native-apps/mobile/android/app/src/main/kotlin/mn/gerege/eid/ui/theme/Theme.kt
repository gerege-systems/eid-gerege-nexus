package mn.gerege.eid.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * eID клиентийн дизайны систем — өнгө нь ширээний `Design/Colors.swift`-ээс
 * ҮҮСГЭГДДЭГ (`scripts/gen_from_swift.py` → EidColors.kt). Тиймээс мак дээр
 * брэндийн өнгө өөрчлөгдвөл энд гараар дагах шаардлагагүй.
 *
 * Тэмдэглэл: энэ бол Gerege Nexus бүрхүүлийн (wallet) палитр БИШ. Хоёр
 * бүтээгдэхүүн, хоёр өнгө — нэгийг нь өөрчлөх нь нөгөөг өөрчлөхгүй.
 */
val LocalEidColors = staticCompositionLocalOf { EidLightColors }

/** Ширээний `Design/Typography.swift`-ийн хэмжээсүүд. */
val EidTypography = Typography(
    headlineLarge = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
    headlineSmall = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
    bodyMedium = TextStyle(fontSize = 14.sp),
    labelMedium = TextStyle(fontSize = 12.sp),
    labelSmall = TextStyle(fontSize = 11.sp),
)

@Composable
fun EidTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) EidDarkColors else EidLightColors
    CompositionLocalProvider(LocalEidColors provides colors) {
        MaterialTheme(
            colorScheme = if (darkTheme) {
                darkColorScheme(
                    primary = colors.eidAccent,
                    onPrimary = Color.White,
                    background = colors.eidSurface,
                    onBackground = colors.textPrimary,
                    surface = colors.eidCardBackground,
                    onSurface = colors.textPrimary,
                    outline = colors.eidCardStroke,
                    error = colors.eidDanger,
                )
            } else {
                lightColorScheme(
                    primary = colors.eidAccent,
                    onPrimary = Color.White,
                    background = colors.eidSurface,
                    onBackground = colors.textPrimary,
                    surface = colors.eidCardBackground,
                    onSurface = colors.textPrimary,
                    outline = colors.eidCardStroke,
                    error = colors.eidDanger,
                )
            },
            typography = EidTypography,
            content = content,
        )
    }
}
