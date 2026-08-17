package app.noted.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.noted.data.Repository
import app.noted.data.api.CableClient
import app.noted.data.api.Network
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteEntity
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class SyncStatus { SYNCING, SYNCED, FAILED }

class BoardViewModel(app: Application) : AndroidViewModel(app) {
    val repo = Repository(app)

    val folders: StateFlow<List<FolderEntity>> =
        repo.observeFolders().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val allNotes: StateFlow<List<NoteEntity>> =
        repo.observeNotes().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val selectedFolder = MutableStateFlow<String?>(null)

    val syncStatus = MutableStateFlow(SyncStatus.SYNCED)

    val notes: StateFlow<List<NoteEntity>> = allNotes

    fun visibleNotes(all: List<NoteEntity>, folderId: String?): List<NoteEntity> =
        if (folderId == null) all else all.filter { it.folderId == folderId }

    private val cable = CableClient(Network.BASE_URL)
    private var cableJob: Job? = null

    init {
        sync()
        listenForNudges()
    }

    private fun listenForNudges() {
        cableJob?.cancel()
        cableJob = viewModelScope.launch {
            cable.nudges().collectLatest {
                sync()
            }
        }
    }

    fun sync() = viewModelScope.launch {
        syncStatus.value = SyncStatus.SYNCING
        syncStatus.value = if (repo.sync.run()) SyncStatus.SYNCED else SyncStatus.FAILED
    }

    fun createFolder(name: String) = viewModelScope.launch { repo.createFolder(name); sync() }
}
