package app.noted.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.noted.data.db.FolderEntity
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.onEach
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
    var edited by remember { mutableStateOf(false) }
    val editorReady = loaded && (folderId == null || folders.any { it.id == folderId })

    LaunchedEffect(noteId) {
        loaded = false
        edited = false
        title = ""; body = ""; folderId = null; pinned = false
        vm.repo.note(noteId)?.let {
            title = it.title.orEmpty(); body = it.body.orEmpty(); folderId = it.folderId; pinned = it.pinned
        }
        loaded = true
    }

    fun worthSaving() = edited && (title.isNotBlank() || body.isNotBlank())

    LaunchedEffect(loaded) {
        if (!loaded) return@LaunchedEffect
        snapshotFlow { listOf(title, body, folderId, pinned) }
            .drop(1)
            .onEach { edited = true }
            .debounce(800)
            .collect { if (worthSaving()) vm.saveNote(noteId, title, body, folderId, pinned) }
    }

    fun close() {
        if (worthSaving()) vm.saveNoteAndSync(noteId, title, body, folderId, pinned) else vm.sync()
        onClose()
    }

    BackHandler { close() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = { close() }) {
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
                Field(
                    title,
                    { title = it },
                    "Title",
                    MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.SemiBold),
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 28.dp),
                )
                Spacer(Modifier.size(10.dp))
                Field(
                    body,
                    { body = it },
                    "Take a note…",
                    MaterialTheme.typography.bodyLarge,
                    Modifier.fillMaxWidth().weight(1f).padding(horizontal = 16.dp),
                )
                FolderPicker(folders, folderId) { folderId = it }
            }
        }
    }
}

@Composable
private fun Field(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
) {
    val color = MaterialTheme.colorScheme.onSurface
    BasicTextField(
        value,
        onValueChange,
        modifier,
        textStyle = style.copy(color = color),
        cursorBrush = SolidColor(color),
    ) { field ->
        if (value.isEmpty()) Text(placeholder, style = style, color = MaterialTheme.colorScheme.onSurfaceVariant)
        field()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FolderPicker(folders: List<FolderEntity>, folderId: String?, onPick: (String?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val sheet = rememberModalBottomSheetState()
    val scope = rememberCoroutineScope()

    TextButton(onClick = { open = true }, modifier = Modifier.padding(horizontal = 8.dp)) {
        Icon(Icons.Outlined.Folder, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(folders.firstOrNull { it.id == folderId }?.name ?: "No folder")
    }

    if (open) {
        fun pick(id: String?) {
            onPick(id)
            scope.launch { sheet.hide() }.invokeOnCompletion { open = false }
        }
        ModalBottomSheet(onDismissRequest = { open = false }, sheetState = sheet) {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).navigationBarsPadding()) {
                Row(
                    Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.Folder, contentDescription = null, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(16.dp))
                    Text("Select folder", style = MaterialTheme.typography.titleMedium)
                }
                FolderRow("No folder", folderId == null) { pick(null) }
                folders.forEach { f -> FolderRow(f.name, folderId == f.id) { pick(f.id) } }
            }
        }
    }
}

@Composable
private fun FolderRow(name: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        name,
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 24.dp, vertical = 16.dp),
        style = MaterialTheme.typography.bodyLarge,
        color = if (selected) MaterialTheme.colorScheme.primary else LocalContentColor.current,
    )
}
