package app.noted.data

import android.content.Context
import app.noted.data.api.Network
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteEntity
import app.noted.data.db.NotedDatabase
import java.util.UUID
import kotlinx.coroutines.flow.Flow

class Repository(context: Context) {
    private val db = NotedDatabase.get(context)
    private val notes = db.noteDao()
    private val folders = db.folderDao()
    val sync = SyncEngine(Network.api(), notes, folders, CursorStore(context))

    fun observeNotes(): Flow<List<NoteEntity>> = notes.observe()
    fun observeFolders(): Flow<List<FolderEntity>> = folders.observe()

    suspend fun note(id: String): NoteEntity? = notes.find(id)

    fun newNoteId(): String = UUID.randomUUID().toString()

    suspend fun saveNote(id: String, title: String, body: String, folderId: String?, pinned: Boolean) {
        val existing = notes.find(id)
        notes.upsert(
            NoteEntity(
                id = id,
                title = title,
                body = body,
                folderId = folderId,
                pinned = pinned,
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

    suspend fun createFolder(name: String) {
        folders.upsert(
            FolderEntity(id = UUID.randomUUID().toString(), name = name, position = Int.MAX_VALUE, pendingCreate = true)
        )
    }
}
