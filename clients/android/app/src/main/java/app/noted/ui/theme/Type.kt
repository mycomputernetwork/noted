package app.noted.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import app.noted.R

@OptIn(ExperimentalTextApi::class)
val Inter = FontFamily(
    Font(R.font.inter_variable, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.inter_variable, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.inter_variable, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.inter_variable, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
)

private val defaults = Typography()

val Typography = Typography(
    displayLarge = defaults.displayLarge.copy(fontFamily = Inter),
    displayMedium = defaults.displayMedium.copy(fontFamily = Inter),
    displaySmall = defaults.displaySmall.copy(fontFamily = Inter),
    headlineLarge = defaults.headlineLarge.copy(fontFamily = Inter),
    headlineMedium = defaults.headlineMedium.copy(fontFamily = Inter),
    headlineSmall = defaults.headlineSmall.copy(fontFamily = Inter),
    titleLarge = defaults.titleLarge.copy(fontFamily = Inter),
    titleMedium = defaults.titleMedium.copy(fontFamily = Inter),
    titleSmall = defaults.titleSmall.copy(fontFamily = Inter),
    bodyLarge = defaults.bodyLarge.copy(fontFamily = Inter),
    bodyMedium = defaults.bodyMedium.copy(fontFamily = Inter),
    bodySmall = defaults.bodySmall.copy(fontFamily = Inter),
    labelLarge = defaults.labelLarge.copy(fontFamily = Inter),
    labelMedium = defaults.labelMedium.copy(fontFamily = Inter),
    labelSmall = defaults.labelSmall.copy(fontFamily = Inter),
)
