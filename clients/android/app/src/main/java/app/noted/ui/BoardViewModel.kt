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

    val notes: StateFlow<List<NoteEntity>> = allNotes

    fun visibleNotes(all: List<NoteEntity>, folderId: String?): List<NoteEntity> =
        if (folderId == null) all else all.filter { it.folderId == folderId }

    private val cable = CableClient(BuildConfig.BASE_URL)
    private var cableJob: Job? = null

    init {
        if (signedIn.value) start()
    }

    fun signInIntent(): Intent = repo.auth.signInIntent()

    fun completeSignIn(intent: Intent) = viewModelScope.launch {
        repo.completeSignIn(intent)
            .onSuccess {
                accountName.value = repo.auth.account?.name ?: repo.auth.account?.email
                signInError.value = null
                signedIn.value = true
                start()
            }
            .onFailure { signInError.value = "Sign-in failed. Try again." }
    }

    fun signOutIntent(): Intent? = repo.auth.signOutIntent()

    fun signOut() = viewModelScope.launch {
        cableJob?.cancel()
        repo.signOut()
        accountName.value = null
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
