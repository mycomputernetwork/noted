package app.noted.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import app.noted.data.db.FolderEntity

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FolderManagerScreen(vm: BoardViewModel, startCreating: Boolean, onBack: () -> Unit) {
    val folders by vm.folders.collectAsState()
    var creating by rememberSaveable { mutableStateOf(startCreating) }
    var newName by rememberSaveable { mutableStateOf("") }
    var editingId by rememberSaveable { mutableStateOf<String?>(null) }
    var editingName by rememberSaveable { mutableStateOf("") }
    var deleteTarget by remember { mutableStateOf<FolderEntity?>(null) }

    fun createFolder() {
        val name = newName.trim()
        if (name.isEmpty()) return
        vm.createFolder(name)
        newName = ""
        creating = false
    }

    fun finishRename(folder: FolderEntity) {
        val name = editingName.trim()
        if (name.isEmpty()) return
        if (name != folder.name) vm.renameFolder(folder.id, name)
        editingId = null
        editingName = ""
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Edit folders") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        }
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())
        ) {
            CreateFolderRow(
                creating = creating,
                name = newName,
                onNameChange = { newName = it },
                onStart = { creating = true; editingId = null },
                onSubmit = ::createFolder,
            )
            HorizontalDivider()
            folders.forEach { folder ->
                if (editingId == folder.id) {
                    EditFolderRow(
                        name = editingName,
                        onNameChange = { editingName = it },
                        onDelete = { deleteTarget = folder },
                        onSubmit = { finishRename(folder) },
                    )
                } else {
                    FolderRow(
                        folder = folder,
                        onEdit = {
                            editingId = folder.id
                            editingName = folder.name
                            creating = false
                        },
                    )
                }
                HorizontalDivider()
            }
        }
    }

    deleteTarget?.let { folder ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("Delete folder?") },
            text = { Text("Notes in ${folder.name} will move to No folder.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        vm.deleteFolder(folder.id)
                        if (editingId == folder.id) {
                            editingId = null
                            editingName = ""
                        }
                        deleteTarget = null
                    },
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { deleteTarget = null }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun CreateFolderRow(
    creating: Boolean,
    name: String,
    onNameChange: (String) -> Unit,
    onStart: () -> Unit,
    onSubmit: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(creating) { if (creating) focusRequester.requestFocus() }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = !creating, onClick = onStart)
            .padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(24.dp))
        FolderTextField(
            value = name,
            onValueChange = onNameChange,
            placeholder = "Create new folder",
            modifier = Modifier.weight(1f).focusRequester(focusRequester),
            enabled = creating,
            onDone = onSubmit,
        )
        if (creating) {
            IconButton(onClick = onSubmit, enabled = name.isNotBlank()) {
                Icon(Icons.Filled.Check, contentDescription = "Create folder")
            }
        }
    }
}

@Composable
private fun FolderRow(folder: FolderEntity, onEdit: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.Folder, contentDescription = null, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(24.dp))
        Text(folder.name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        IconButton(onClick = onEdit) {
            Icon(Icons.Filled.Edit, contentDescription = "Rename ${folder.name}")
        }
    }
}

@Composable
private fun EditFolderRow(
    name: String,
    onNameChange: (String) -> Unit,
    onDelete: () -> Unit,
    onSubmit: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Row(
        modifier = Modifier.fillMaxWidth().padding(start = 4.dp, end = 16.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onDelete) {
            Icon(Icons.Filled.Delete, contentDescription = "Delete folder")
        }
        Spacer(Modifier.width(12.dp))
        FolderTextField(
            value = name,
            onValueChange = onNameChange,
            placeholder = "Folder name",
            modifier = Modifier.weight(1f).focusRequester(focusRequester),
            onDone = onSubmit,
        )
        IconButton(onClick = onSubmit, enabled = name.isNotBlank()) {
            Icon(Icons.Filled.Check, contentDescription = "Save folder")
        }
    }
}

@Composable
private fun FolderTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier,
    enabled: Boolean = true,
    onDone: () -> Unit,
) {
    val color = MaterialTheme.colorScheme.onSurface
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        enabled = enabled,
        textStyle = MaterialTheme.typography.bodyLarge.copy(color = color),
        singleLine = true,
        cursorBrush = SolidColor(color),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
    ) { field ->
        if (value.isEmpty()) {
            Text(placeholder, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        field()
    }
}
