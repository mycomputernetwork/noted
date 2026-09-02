package app.noted.data

import android.content.Context
import android.content.Intent
import app.noted.data.api.Network
import app.noted.data.auth.AuthManager
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteEntity
import app.noted.data.db.NotedDatabase
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext

class Repository(context: Context) {
    val auth = AuthManager(context)

    private val db = NotedDatabase.get(context)
    private val notes = db.noteDao()
    private val folders = db.folderDao()
    private val cursor = CursorStore(context)
    private val network = Network(auth)

    val sync = SyncEngine(network.api, notes, folders, cursor)

    fun observeNotes(): Flow<List<NoteEntity>> = notes.observe()
    fun observeFolders(): Flow<List<FolderEntity>> = folders.observe()

    suspend fun note(id: String): NoteEntity? = notes.find(id)

    fun newNoteId(): String = UUID.randomUUID().toString()

    // Tokens without an account are a sign-in that only looks finished: drop
    // them, or the next launch opens a board that can never sync.
    suspend fun completeSignIn(intent: Intent): Result<Unit> = auth.exchange(intent).mapCatching {
        val idToken = auth.idToken ?: error("auth returned no ID token")
        val user = network.api.session("Bearer $idToken")

        if (auth.account?.id != user.id) wipeLocal()
        auth.account = user
    }.onFailure { auth.signOut() }

    suspend fun signOut() {
        auth.signOut()
        wipeLocal()
    }

    fun close() = auth.close()

    // The cache is not scoped by user: a second account must not open the first one's notes.
    private suspend fun wipeLocal() {
        withContext(Dispatchers.IO) { db.clearAllTables() }
        cursor.clear()
    }

    suspend fun saveNote(id: String, title: String, body: String, folderId: String?, pinned: Boolean) {
        val existing = notes.find(id)
        val folderBoardPosition = when {
            existing?.folderId == folderId -> existing?.folderBoardPosition
            folderId == null -> null
            else -> (notes.folderBoardFront(folderId, id) ?: 0) - 1
        }
        notes.upsert(
            NoteEntity(
                id = id,
                title = title,
                body = body,
                folderId = folderId,
                pinned = pinned,
                boardPosition = existing?.boardPosition,
                folderBoardPosition = folderBoardPosition,
                updatedAt = existing?.updatedAt,
                dirty = true,
                pendingCreate = existing == null || existing.pendingCreate,
            )
        )
    }

    suspend fun deleteNote(id: String) {
        val existing = notes.find(id) ?: return
        if (existing.pendingCreate) notes.delete(id)
        else notes.upsert(existing.copy(pendingDelete = true))
    }

    suspend fun reorderNotes(ids: List<String>, folderId: String?) {
        ids.forEachIndexed { index, id ->
            if (folderId == null) notes.updateBoardPosition(id, index)
            else notes.updateFolderBoardPosition(id, index)
        }
    }

    suspend fun createFolder(name: String) {
        val lastPosition = folders.maxPosition() ?: -1
        folders.upsert(
            FolderEntity(
                id = UUID.randomUUID().toString(),
                name = name,
                position = if (lastPosition == Int.MAX_VALUE) Int.MAX_VALUE else lastPosition + 1,
                pendingCreate = true,
            )
        )
    }

    suspend fun renameFolder(id: String, name: String) {
        val folder = folders.find(id) ?: return
        folders.upsert(folder.copy(name = name, dirty = true))
    }

    suspend fun deleteFolder(id: String) {
        val folder = folders.find(id) ?: return
        notes.unfileFromFolder(id)
        if (folder.pendingCreate) folders.delete(id)
        else folders.upsert(folder.copy(pendingDelete = true))
    }
}
