package app.noted.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.noted.R
import kotlinx.coroutines.delay

private val BoilFrames = listOf(
    R.drawable.noted_wordmark_boil_0,
    R.drawable.noted_wordmark_boil_1,
    R.drawable.noted_wordmark_boil_2,
)

@Composable
fun Logo(modifier: Modifier = Modifier, height: Dp = 22.dp) {
    Image(
        painter = painterResource(R.drawable.noted_wordmark),
        contentDescription = "noted",
        modifier = modifier.height(height),
        colorFilter = ColorFilter.tint(MaterialTheme.colorScheme.onSurface),
    )
}

@Composable
fun BoilingLogo(modifier: Modifier = Modifier, height: Dp = 44.dp) {
    var frame by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(130)
            frame = (frame + 1) % BoilFrames.size
        }
    }
    Image(
        painter = painterResource(BoilFrames[frame]),
        contentDescription = "noted",
        modifier = modifier.height(height),
        colorFilter = ColorFilter.tint(MaterialTheme.colorScheme.onSurface),
    )
}
