package app.noted.ui

import android.app.Application
import android.content.Intent
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.noted.BuildConfig
import app.noted.data.Repository
import app.noted.data.api.CableClient
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

    val signedIn = MutableStateFlow(repo.auth.isSignedIn())

    val accountName = MutableStateFlow(repo.auth.account?.name ?: repo.auth.account?.email)

    val signInError = MutableStateFlow<String?>(null)

    val signInInProgress = MutableStateFlow(false)

    val notes: StateFlow<List<NoteEntity>> = allNotes

    fun visibleNotes(all: List<NoteEntity>, folderId: String?): List<NoteEntity> =
        if (folderId == null) {
            all.sortedWith(allBoardOrder)
        } else {
            all.filter { it.folderId == folderId }.sortedWith(folderBoardOrder)
        }

    fun moveNote(
        visible: List<NoteEntity>,
        folderId: String?,
        draggedId: String,
        targetId: String,
    ) = viewModelScope.launch {
        val from = visible.indexOfFirst { it.id == draggedId }
        val to = visible.indexOfFirst { it.id == targetId }
        if (from == -1 || to == -1 || from == to) return@launch
        if (visible[from].pinned != visible[to].pinned) return@launch

        val ids = visible.toMutableList().apply { add(to, removeAt(from)) }.map { it.id }
        repo.reorderNotes(ids, folderId)
    }

    private val allBoardOrder = compareByDescending<NoteEntity> { it.pinned }
        .thenBy { it.boardPosition == null }
        .thenBy { it.boardPosition ?: Int.MAX_VALUE }
        .thenByDescending { it.updatedAt ?: "" }
        .thenByDescending { it.id }

    private val folderBoardOrder = compareByDescending<NoteEntity> { it.pinned }
        .thenBy { it.folderSortPosition() == null }
        .thenBy { it.folderSortPosition() ?: Int.MAX_VALUE }
        .thenByDescending { it.updatedAt ?: "" }
        .thenByDescending { it.id }

    private fun NoteEntity.folderSortPosition(): Int? = folderBoardPosition ?: boardPosition

    private val cable = CableClient(BuildConfig.BASE_URL) { repo.auth.freshAccessToken() }
    private var cableJob: Job? = null

    init {
        if (signedIn.value) start()
    }

    fun signInIntent(): Intent {
        signInInProgress.value = true
        signInError.value = null
        return repo.auth.signInIntent()
    }

    fun cancelSignIn() {
        signInInProgress.value = false
    }

    fun completeSignIn(intent: Intent) = viewModelScope.launch {
        repo.completeSignIn(intent)
            .onSuccess {
                accountName.value = repo.auth.account?.name ?: repo.auth.account?.email
                signInError.value = null
                signedIn.value = true
                start()
            }
            .onFailure { signInError.value = "Sign-in failed. Try again." }
        signInInProgress.value = false
    }

    fun signOutIntent(): Intent? = repo.auth.signOutIntent()

    fun signOut() = viewModelScope.launch {
        cableJob?.cancel()
        repo.signOut()
        accountName.value = null
        signInInProgress.value = false
        signedIn.value = false
    }

    private fun start() {
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
        signedIn.value = repo.auth.isSignedIn()
    }

    override fun onCleared() = repo.close()

    fun createFolder(name: String) = viewModelScope.launch { repo.createFolder(name); sync() }
}
