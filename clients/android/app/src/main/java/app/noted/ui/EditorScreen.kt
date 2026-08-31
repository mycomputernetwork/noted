package app.noted.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, kotlinx.coroutines.FlowPreview::class)
@Composable
fun EditorScreen(vm: BoardViewModel, noteId: String, onClose: () -> Unit) {
    val folders by vm.folders.collectAsState()
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var folderId by remember { mutableStateOf<String?>(null) }
    var pinned by remember { mutableStateOf(false) }
    var loaded by remember { mutableStateOf(false) }
    val editorReady = loaded && (folderId == null || folders.any { it.id == folderId })
    val scope = rememberCoroutineScope()

    LaunchedEffect(noteId) {
        loaded = false
        title = ""; body = ""; folderId = null; pinned = false
        vm.repo.note(noteId)?.let {
            title = it.title.orEmpty(); body = it.body.orEmpty(); folderId = it.folderId; pinned = it.pinned
        }
        loaded = true
    }

    fun save() = scope.launch {
        if (title.isBlank() && body.isBlank()) return@launch
        vm.repo.saveNote(noteId, title, body, folderId, pinned)
    }

    LaunchedEffect(loaded) {
        if (!loaded) return@LaunchedEffect
        snapshotFlow { listOf(title, body, folderId, pinned) }.debounce(800).collect { save() }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = { save(); vm.sync(); onClose() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { pinned = !pinned }) {
                        Icon(Icons.Filled.PushPin, contentDescription = "Pin", tint = if (pinned) Color(0xFFE0A050) else Color.Gray)
                    }
                },
            )
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (editorReady) {
                val transparent = TextFieldDefaults.colors(
                    unfocusedContainerColor = Color.Transparent,
                    focusedContainerColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                )
                LazyRow(Modifier.padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item { FilterChip(folderId == null, { folderId = null }, label = { Text("None") }) }
                    items(folders) { f ->
                        FilterChip(folderId == f.id, { folderId = f.id }, label = { Text(f.name) })
                    }
                }
                TextField(
                    title,
                    { title = it },
                    Modifier.fillMaxWidth(),
                    placeholder = { Text("Title") },
                    colors = transparent,
                    textStyle = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.SemiBold),
                )
                TextField(body, { body = it }, Modifier.fillMaxSize(), placeholder = { Text("Take a note…") }, colors = transparent)
            }
        }
    }
}
