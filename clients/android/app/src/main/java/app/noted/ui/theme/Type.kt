package app.noted.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import app.noted.R

@OptIn(ExperimentalTextApi::class)
val Inter = FontFamily(
    Font(R.font.inter_variable, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.inter_variable, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(550))),
    Font(R.font.inter_variable, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(650))),
    Font(R.font.inter_variable, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
)

// Material's scale tracks every size positively, which Inter is not drawn for: it
// carries its own optical spacing and only wants tightening as the size grows.
// Uppercase labels are the exception and keep the web's 0.09em.
private fun inter(
    size: TextUnit,
    lineHeight: TextUnit,
    weight: FontWeight = FontWeight.Normal,
    tracking: TextUnit = 0.sp,
) = TextStyle(
    fontFamily = Inter,
    fontWeight = weight,
    fontSize = size,
    lineHeight = lineHeight,
    letterSpacing = tracking,
    platformStyle = PlatformTextStyle(includeFontPadding = false),
    lineHeightStyle = LineHeightStyle(
        alignment = LineHeightStyle.Alignment.Center,
        trim = LineHeightStyle.Trim.None,
    ),
)

val Typography = Typography(
    displayLarge = inter(40.sp, 46.sp, FontWeight.SemiBold, (-1.2).sp),
    displayMedium = inter(34.sp, 40.sp, FontWeight.SemiBold, (-0.9).sp),
    displaySmall = inter(28.sp, 34.sp, FontWeight.SemiBold, (-0.7).sp),
    headlineLarge = inter(26.sp, 32.sp, FontWeight.SemiBold, (-0.6).sp),
    headlineMedium = inter(22.sp, 28.sp, FontWeight.Medium, (-0.45).sp),
    headlineSmall = inter(20.sp, 26.sp, FontWeight.Medium, (-0.35).sp),
    titleLarge = inter(21.sp, 26.sp, FontWeight.Medium, (-0.35).sp),
    titleMedium = inter(17.sp, 22.sp, FontWeight.Medium, (-0.25).sp),
    titleSmall = inter(15.sp, 19.sp, FontWeight.Medium, (-0.15).sp),
    bodyLarge = inter(17.sp, 25.sp, tracking = (-0.2).sp),
    bodyMedium = inter(14.sp, 19.sp, tracking = (-0.1).sp),
    bodySmall = inter(13.sp, 18.sp),
    labelLarge = inter(14.sp, 18.sp, FontWeight.Medium, (-0.1).sp),
    labelMedium = inter(11.sp, 14.sp, FontWeight.SemiBold, 1.0.sp),
    labelSmall = inter(11.sp, 14.sp, FontWeight.Medium, 0.4.sp),
)
