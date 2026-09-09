package app.noted.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// The board is --surface. A note is --surface-sunken wherever it appears, which
// is the tone the header and the rail already carry.
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
    background = Surface,
    onBackground = TextPrimary,
    surface = Surface,
    onSurface = TextPrimary,
    surfaceVariant = SurfaceRaised,
    onSurfaceVariant = TextDim,
    surfaceTint = Accent,
    surfaceBright = SurfaceOverlay,
    surfaceDim = SurfaceSunken,
    surfaceContainerLowest = SurfaceSunken,
    surfaceContainerLow = SurfaceSunken,
    surfaceContainer = Surface,
    surfaceContainerHigh = SurfaceRaised,
    surfaceContainerHighest = SurfaceOverlay,
    inverseSurface = TextPrimary,
    inverseOnSurface = Surface,
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
