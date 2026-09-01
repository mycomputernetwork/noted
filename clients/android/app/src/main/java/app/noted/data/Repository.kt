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
        notes.upsert(
            NoteEntity(
                id = id,
                title = title,
                body = body,
                folderId = folderId,
                pinned = pinned,
                boardPosition = existing?.boardPosition,
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

    suspend fun reorderNotes(ids: List<String>) {
        ids.forEachIndexed { index, id -> notes.updateBoardPosition(id, index) }
    }

    suspend fun createFolder(name: String) {
        folders.upsert(
            FolderEntity(id = UUID.randomUUID().toString(), name = name, position = Int.MAX_VALUE, pendingCreate = true)
        )
    }
}
