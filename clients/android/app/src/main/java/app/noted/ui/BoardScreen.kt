package app.noted.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.material3.NavigationDrawerItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteEntity
import app.noted.ui.theme.TextFaint
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
                Column {
                    TopAppBar(
                        title = { Logo() },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
                        ),
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
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                }
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
                contentPadding = PaddingValues(8.dp),
                verticalItemSpacing = 8.dp,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
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
            modifier = Modifier.padding(top = 12.dp, bottom = 6.dp),
            style = MaterialTheme.typography.labelMedium,
            color = TextFaint,
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

    // Bounds keep moving as cards reorder mid-drag; hit-testing against that live
    // map is what made the board reshuffle on every frame instead of settling.
    // One snapshot, taken where the drag began, is what the rest of the gesture
    // measures against.
    private var slots: List<Pair<String, Rect>> = emptyList()

    fun start(noteId: String, offset: Offset, section: Set<String>) {
        id = noteId
        target = null
        grab = offset
        point = (bounds[noteId]?.topLeft ?: Offset.Zero) + offset
        slots = bounds.filterKeys { it in section }.toList()
    }

    fun end() {
        id = null
        target = null
        slots = emptyList()
    }

    // Nearest slot by distance to its edge, not its centre: two cards of very
    // different heights leave a masonry grid with dead space between them that a
    // plain "is the finger over this card" test never resolves, and the drag
    // stalls there instead of picking up the card underneath.
    fun nearest(excluding: String): String? {
        var nearestId: String? = null
        var shortest = Float.MAX_VALUE

        for ((slotId, rect) in slots) {
            if (slotId == excluding) continue

            val dx = maxOf(rect.left - point.x, 0f, point.x - rect.right)
            val dy = maxOf(rect.top - point.y, 0f, point.y - rect.bottom)
            val distance = dx * dx + dy * dy
            if (distance >= shortest) continue

            shortest = distance
            nearestId = slotId
        }

        return nearestId
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
    // The pinned/others split is two grids sharing one drag: a slot snapshot
    // taken from just this section keeps a drag from ever landing across it.
    val section = notes.map { it.id }.toSet()

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
                        onDragStart = { offset -> drag.start(note.id, offset, section) },
                        onDrag = { change, amount ->
                            change.consume()
                            drag.point += amount
                            val targetId = drag.nearest(note.id)
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
    ModalDrawerSheet(
        modifier = Modifier.width(268.dp),
        drawerContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 14.dp, top = 20.dp, end = 14.dp, bottom = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.AccountCircle,
                contentDescription = name ?: "Account",
                modifier = Modifier.size(26.dp),
                tint = TextFaint,
            )
            Spacer(Modifier.width(10.dp))
            Text(
                name ?: "Signed in",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        DrawerRow("All notes", selected = selectedFolder == null) { onSelectFolder(null) }
        HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.outlineVariant)
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "FOLDERS",
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.labelMedium,
                color = TextFaint,
            )
            TextButton(onClick = onManageFolders) {
                Text("Edit", style = MaterialTheme.typography.labelLarge)
            }
        }
        folders.forEach { folder ->
            DrawerRow(
                label = folder.name,
                selected = selectedFolder == folder.id,
                icon = { Icon(Icons.Outlined.Folder, contentDescription = null, modifier = Modifier.size(16.dp)) },
            ) { onSelectFolder(folder.id) }
        }
        DrawerRow(
            label = "Create new folder",
            selected = false,
            icon = { Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(16.dp)) },
            onClick = onCreateFolder,
        )
        HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.outlineVariant)
        DrawerRow("Sign out", selected = false, onClick = onSignOut)
    }
}

// The web rail's rows are 26px tall; Material's 56dp default reads as a different
// app beside it.
@Composable
private fun DrawerRow(
    label: String,
    selected: Boolean,
    icon: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    NavigationDrawerItem(
        selected = selected,
        icon = icon,
        label = { Text(label, style = MaterialTheme.typography.labelLarge) },
        onClick = onClick,
        shape = RoundedCornerShape(6.dp),
        colors = NavigationDrawerItemDefaults.colors(
            unselectedContainerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
            unselectedIconColor = TextFaint,
        ),
        modifier = Modifier.padding(horizontal = 8.dp, vertical = 1.dp).height(36.dp),
    )
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
        shape = RoundedCornerShape(12.dp),
        // Material tints a card's fill by its elevation and holds a hovered and a
        // dragged elevation back when only the resting one is given, so every state
        // is pinned to zero: the card is the board with a border round it.
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.background),
        elevation = CardDefaults.cardElevation(0.dp, 0.dp, 0.dp, 0.dp, 0.dp, 0.dp),
        border = BorderStroke(
            1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
        ),
    ) {
        val title = note.title?.takeIf { it.isNotBlank() }
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (title != null) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (!note.body.isNullOrBlank()) {
                Text(
                    text = note.body,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = if (title != null) 10 else 12,
                    overflow = TextOverflow.Ellipsis,
                )
            } else if (title == null) {
                Text("Empty note", style = MaterialTheme.typography.bodyMedium, color = TextFaint)
            }
        }
    }
}
