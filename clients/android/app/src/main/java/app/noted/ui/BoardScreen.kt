package app.noted.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.staggeredgrid.LazyStaggeredGridScope
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridItemSpan
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.Stable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteEntity
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BoardScreen(
    vm: BoardViewModel,
    onOpenNote: (String) -> Unit,
    onNewNote: () -> Unit,
    onSignOut: () -> Unit,
    onManageFolders: () -> Unit,
    onCreateFolder: () -> Unit,
) {
    val folders by vm.folders.collectAsState()
    val allNotes by vm.notes.collectAsState()
    val selected by vm.selectedFolder.collectAsState()
    val status by vm.syncStatus.collectAsState()
    val account by vm.accountName.collectAsState()
    val notes = vm.visibleNotes(allNotes, selected)
    val pinnedNotes = notes.filter { it.pinned }
    val otherNotes = notes.filterNot { it.pinned }
    val currentNotes by rememberUpdatedState(notes)
    val currentFolderId by rememberUpdatedState(selected)
    val drag = remember { DragState() }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            AppDrawer(
                name = account,
                folders = folders,
                selectedFolder = selected,
                onSelectFolder = { folderId ->
                    vm.selectedFolder.value = folderId
                    scope.launch { drawerState.close() }
                },
                onManageFolders = {
                    scope.launch { drawerState.close() }
                    onManageFolders()
                },
                onCreateFolder = {
                    scope.launch { drawerState.close() }
                    onCreateFolder()
                },
                onSignOut = onSignOut,
            )
        },
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Logo() },
                    navigationIcon = {
                        IconButton(onClick = { scope.launch { drawerState.open() } }) {
                            Icon(Icons.Filled.Menu, contentDescription = "Menu")
                        }
                    },
                    actions = {
                        IconButton(onClick = { vm.sync() }) {
                            SyncIndicator(status)
                        }
                    },
                )
            },
            floatingActionButton = {
                FloatingActionButton(onClick = onNewNote) {
                    Icon(Icons.Filled.Add, contentDescription = "New note")
                }
            }
        ) { padding ->
            LazyVerticalStaggeredGrid(
                columns = StaggeredGridCells.Fixed(2),
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = PaddingValues(12.dp),
                verticalItemSpacing = 12.dp,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = StaggeredGridItemSpan.FullLine) {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        item {
                            FilterChip(selected = selected == null, onClick = { vm.selectedFolder.value = null }, label = { Text("All") })
                        }
                        items(folders) { f ->
                            FilterChip(
                                selected = selected == f.id,
                                onClick = { vm.selectedFolder.value = f.id },
                                label = { Text(f.name) },
                            )
                        }
                    }
                }
                if (pinnedNotes.isNotEmpty()) {
                    sectionHeader("Pinned")
                    noteCards(pinnedNotes, drag, { currentNotes }, { currentFolderId }, onOpenNote, vm)
                }

                if (otherNotes.isNotEmpty()) {
                    sectionHeader(if (pinnedNotes.isEmpty()) "Notes" else "Others")
                    noteCards(otherNotes, drag, { currentNotes }, { currentFolderId }, onOpenNote, vm)
                }
            }
        }
    }
}

private fun LazyStaggeredGridScope.sectionHeader(label: String) {
    item(span = StaggeredGridItemSpan.FullLine) {
        Text(
            text = label.uppercase(),
            modifier = Modifier.padding(top = 8.dp, bottom = 2.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

// The card is drawn under the finger by offsetting it from the slot it still occupies,
// so a reorder mid-drag re-anchors it instead of leaving it a gesture behind.
@Stable
private class DragState {
    val bounds = mutableStateMapOf<String, Rect>()
    var id by mutableStateOf<String?>(null)
    var point by mutableStateOf(Offset.Zero)
    var grab by mutableStateOf(Offset.Zero)
    var target by mutableStateOf<String?>(null)

    fun end() {
        id = null
        target = null
    }
}

private fun LazyStaggeredGridScope.noteCards(
    notes: List<NoteEntity>,
    drag: DragState,
    currentNotes: () -> List<NoteEntity>,
    currentFolderId: () -> String?,
    onOpenNote: (String) -> Unit,
    vm: BoardViewModel,
) {
    items(notes, key = { it.id }) { note ->
        DisposableEffect(note.id) {
            onDispose { drag.bounds.remove(note.id) }
        }

        val dragging = drag.id == note.id

        NoteCard(
            note,
            selected = dragging,
            modifier = Modifier
                .zIndex(if (dragging) 1f else 0f)
                .animateItem()
                .onGloballyPositioned { drag.bounds[note.id] = it.boundsInRoot() }
                .pointerInput(note.id) {
                    detectDragGesturesAfterLongPress(
                        onDragStart = { offset ->
                            drag.id = note.id
                            drag.target = null
                            drag.grab = offset
                            drag.point = (drag.bounds[note.id]?.topLeft ?: Offset.Zero) + offset
                        },
                        onDrag = { change, amount ->
                            change.consume()
                            drag.point += amount
                            val targetId = drag.bounds.entries
                                .firstOrNull { (id, bounds) -> id != note.id && bounds.contains(drag.point) }
                                ?.key
                            if (targetId != null && targetId != drag.target) {
                                drag.target = targetId
                                vm.moveNote(currentNotes(), currentFolderId(), note.id, targetId)
                            }
                        },
                        onDragEnd = {
                            drag.end()
                            vm.sync()
                        },
                        onDragCancel = { drag.end() },
                    )
                }
                .graphicsLayer {
                    if (drag.id != note.id) return@graphicsLayer
                    val origin = drag.bounds[note.id]?.topLeft ?: return@graphicsLayer
                    translationX = drag.point.x - drag.grab.x - origin.x
                    translationY = drag.point.y - drag.grab.y - origin.y
                    scaleX = LIFT_SCALE
                    scaleY = LIFT_SCALE
                },
        ) { onOpenNote(note.id) }
    }
}

private const val LIFT_SCALE = 1.03f

@Composable
private fun AppDrawer(
    name: String?,
    folders: List<FolderEntity>,
    selectedFolder: String?,
    onSelectFolder: (String?) -> Unit,
    onManageFolders: () -> Unit,
    onCreateFolder: () -> Unit,
    onSignOut: () -> Unit,
) {
    ModalDrawerSheet {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 24.dp, end = 16.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.AccountCircle,
                contentDescription = name ?: "Account",
                modifier = Modifier.size(32.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.width(12.dp))
            Text(name ?: "Signed in", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        NavigationDrawerItem(
            selected = selectedFolder == null,
            label = { Text("All notes") },
            onClick = { onSelectFolder(null) },
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 24.dp, end = 16.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "Folders",
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextButton(onClick = onManageFolders) { Text("Edit") }
        }
        folders.forEach { folder ->
            NavigationDrawerItem(
                selected = selectedFolder == folder.id,
                icon = { Icon(Icons.Outlined.Folder, contentDescription = null) },
                label = { Text(folder.name) },
                onClick = { onSelectFolder(folder.id) },
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 2.dp),
            )
        }
        NavigationDrawerItem(
            selected = false,
            icon = { Icon(Icons.Filled.Add, contentDescription = null) },
            label = { Text("Create new folder") },
            onClick = onCreateFolder,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 2.dp),
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        NavigationDrawerItem(
            selected = false,
            label = { Text("Sign out") },
            onClick = onSignOut,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
        )
    }
}

@Composable
private fun SyncIndicator(status: SyncStatus) {
    when (status) {
        SyncStatus.SYNCING -> CircularProgressIndicator(
            modifier = Modifier.size(20.dp),
            strokeWidth = 2.dp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SyncStatus.SYNCED -> Icon(
            Icons.Filled.CloudDone, contentDescription = "Synced",
            modifier = Modifier.size(22.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SyncStatus.FAILED -> Icon(
            Icons.Filled.CloudOff, contentDescription = "Not synced",
            modifier = Modifier.size(22.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun NoteCard(note: NoteEntity, modifier: Modifier = Modifier, selected: Boolean = false, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = modifier,
        border = if (selected) BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
    ) {
        val title = note.title?.takeIf { it.isNotBlank() }
        Text(
            text = title ?: note.body.orEmpty(),
            modifier = Modifier.padding(14.dp),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = if (title != null) FontWeight.SemiBold else FontWeight.Normal,
            maxLines = if (title != null) 2 else 8,
        )
        if (title != null && !note.body.isNullOrBlank()) {
            Text(
                text = note.body,
                modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 14.dp),
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 10,
            )
        }
    }
}
