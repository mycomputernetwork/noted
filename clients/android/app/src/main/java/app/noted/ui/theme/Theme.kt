package app.noted.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// One flat tone for everything the app draws: board, card, editor, header, rail.
// A card is told apart by its border, as on the web. Only what lifts above the
// screen — menus, sheets, dialogs — gets a raised tone.
private val NotedColorScheme = darkColorScheme(
    primary = Accent,
    onPrimary = AccentContrast,
    primaryContainer = Accent,
    onPrimaryContainer = AccentContrast,
    secondary = Accent,
    onSecondary = AccentContrast,
    secondaryContainer = AccentTint,
    onSecondaryContainer = Accent,
    tertiary = Accent,
    onTertiary = AccentContrast,
    background = SurfaceSunken,
    onBackground = TextPrimary,
    surface = SurfaceSunken,
    onSurface = TextPrimary,
    surfaceVariant = SurfaceRaised,
    onSurfaceVariant = TextDim,
    surfaceTint = Accent,
    surfaceBright = SurfaceOverlay,
    surfaceDim = SurfaceSunken,
    surfaceContainerLowest = SurfaceSunken,
    surfaceContainerLow = SurfaceSunken,
    surfaceContainer = SurfaceSunken,
    surfaceContainerHigh = SurfaceRaised,
    surfaceContainerHighest = SurfaceOverlay,
    inverseSurface = TextPrimary,
    inverseOnSurface = SurfaceSunken,
    outline = BorderStrong,
    outlineVariant = Border,
    error = Danger,
    onError = AccentContrast,
    errorContainer = Danger,
    onErrorContainer = AccentContrast,
    scrim = Color.Black,
)

@Composable
fun NotedTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = NotedColorScheme,
        typography = Typography,
        content = content,
    )
}
