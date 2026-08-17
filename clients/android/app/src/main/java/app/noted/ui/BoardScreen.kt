package app.noted.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.noted.data.db.NoteEntity

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BoardScreen(vm: BoardViewModel, onOpenNote: (String) -> Unit, onNewNote: () -> Unit) {
    val folders by vm.folders.collectAsState()
    val allNotes by vm.notes.collectAsState()
    val selected by vm.selectedFolder.collectAsState()
    val status by vm.syncStatus.collectAsState()
    val notes = vm.visibleNotes(allNotes, selected)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Logo() },
                actions = { SyncIndicator(status); androidx.compose.foundation.layout.Spacer(Modifier.size(12.dp)) },
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
            item(span = androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridItemSpan.FullLine) {
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
            items(notes, key = { it.id }) { note ->
                NoteCard(note) { onOpenNote(note.id) }
            }
        }
    }
}

@Composable
private fun Logo() {
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("not") }
            withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = Color(0xFFE0A050))) { append("ed") }
        },
        fontSize = 22.sp,
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
private fun NoteCard(note: NoteEntity, onClick: () -> Unit) {
    Card(onClick = onClick) {
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
