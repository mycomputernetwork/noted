package app.noted.ui

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

@Composable
fun Logo(modifier: Modifier = Modifier, fontSize: TextUnit = 22.sp) {
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("not") }
            withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = Color(0xFFE0A050))) { append("ed") }
        },
        modifier = modifier,
        fontSize = fontSize,
    )
}
