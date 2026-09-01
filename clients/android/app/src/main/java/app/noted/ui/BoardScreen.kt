package app.noted.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.staggeredgrid.LazyStaggeredGridScope
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridItemSpan
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
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
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.noted.data.db.NoteEntity
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BoardScreen(vm: BoardViewModel, onOpenNote: (String) -> Unit, onNewNote: () -> Unit, onSignOut: () -> Unit) {
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
    val cardBounds = remember { mutableStateMapOf<String, androidx.compose.ui.geometry.Rect>() }
    var draggedId by remember { mutableStateOf<String?>(null) }
    var dragPoint by remember { mutableStateOf(Offset.Zero) }
    var lastTargetId by remember { mutableStateOf<String?>(null) }
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = { AccountDrawer(account, onSignOut) },
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
                ExtendedFloatingActionButton(
                    onClick = onNewNote,
                    icon = { Icon(Icons.Filled.Add, contentDescription = "New note") },
                    text = { Text("Note") },
                )
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
                    noteCards(
                        pinnedNotes,
                        draggedId,
                        cardBounds,
                        { currentNotes },
                        { currentFolderId },
                        { dragPoint },
                        { lastTargetId },
                        onOpenNote,
                        vm,
                        onDragged = { draggedId = it },
                        onDragPoint = { dragPoint = it },
                        onLastTarget = { lastTargetId = it },
                    )
                }

                if (otherNotes.isNotEmpty()) {
                    sectionHeader(if (pinnedNotes.isEmpty()) "Notes" else "Others")
                    noteCards(
                        otherNotes,
                        draggedId,
                        cardBounds,
                        { currentNotes },
                        { currentFolderId },
                        { dragPoint },
                        { lastTargetId },
                        onOpenNote,
                        vm,
                        onDragged = { draggedId = it },
                        onDragPoint = { dragPoint = it },
                        onLastTarget = { lastTargetId = it },
                    )
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

private fun LazyStaggeredGridScope.noteCards(
    notes: List<NoteEntity>,
    draggedId: String?,
    cardBounds: MutableMap<String, Rect>,
    currentNotes: () -> List<NoteEntity>,
    currentFolderId: () -> String?,
    dragPoint: () -> Offset,
    lastTargetId: () -> String?,
    onOpenNote: (String) -> Unit,
    vm: BoardViewModel,
    onDragged: (String?) -> Unit,
    onDragPoint: (Offset) -> Unit,
    onLastTarget: (String?) -> Unit,
) {
    items(notes, key = { it.id }) { note ->
        NoteCard(
            note,
            selected = draggedId == note.id,
            modifier = Modifier
                .animateItem()
                .onGloballyPositioned { cardBounds[note.id] = it.boundsInRoot() }
                .pointerInput(note.id) {
                    detectDragGesturesAfterLongPress(
                        onDragStart = { offset ->
                            onDragged(note.id)
                            onLastTarget(null)
                            onDragPoint((cardBounds[note.id]?.topLeft ?: Offset.Zero) + offset)
                        },
                        onDrag = { change, amount ->
                            change.consume()
                            val point = dragPoint() + amount
                            onDragPoint(point)
                            val targetId = cardBounds.entries
                                .firstOrNull { (id, bounds) -> id != note.id && bounds.contains(point) }
                                ?.key
                            if (targetId != null && targetId != lastTargetId()) {
                                onLastTarget(targetId)
                                vm.moveNote(currentNotes(), currentFolderId(), note.id, targetId)
                            }
                        },
                        onDragEnd = {
                            onDragged(null)
                            onLastTarget(null)
                            vm.sync()
                        },
                        onDragCancel = {
                            onDragged(null)
                            onLastTarget(null)
                        },
                    )
                },
        ) { onOpenNote(note.id) }
    }
}

@Composable
private fun AccountDrawer(name: String?, onSignOut: () -> Unit) {
    ModalDrawerSheet {
        Icon(
            Icons.Filled.AccountCircle,
            contentDescription = name ?: "Account",
            modifier = Modifier.padding(start = 16.dp, top = 24.dp).size(32.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            name ?: "Signed in",
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        HorizontalDivider()
        NavigationDrawerItem(
            selected = false,
            label = { Text("Sign out") },
            onClick = onSignOut,
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
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
