package app.noted.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.noted.R

@Composable
fun Logo(modifier: Modifier = Modifier, height: Dp = 22.dp) {
    Image(
        painter = painterResource(R.drawable.noted_wordmark),
        contentDescription = "noted",
        modifier = modifier.height(height),
        colorFilter = ColorFilter.tint(MaterialTheme.colorScheme.onSurface),
    )
}
