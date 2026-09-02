package app.noted.data

import app.noted.data.api.FolderBody
import app.noted.data.api.FolderFields
import app.noted.data.api.NoteBody
import app.noted.data.api.NoteFields
import app.noted.data.api.NotedApi
import app.noted.data.db.FolderDao
import app.noted.data.db.FolderEntity
import app.noted.data.db.NoteDao
import app.noted.data.db.NoteEntity
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import retrofit2.HttpException

class SyncEngine(
    private val api: NotedApi,
    private val notes: NoteDao,
    private val folders: FolderDao,
    private val cursor: CursorStore,
) {
    private val lock = Mutex()

    suspend fun run(): Boolean = lock.withLock {
        try {
            push()
            pull()
            true
        } catch (e: Exception) {
            if (app.noted.BuildConfig.DEBUG) android.util.Log.e("SyncEngine", "sync failed", e)
            false
        }
    }

    private suspend fun push() {
        for (f in folders.pending()) pushFolder(f)
        for (n in notes.pending()) pushNote(n)
    }

    private suspend fun pushNote(n: NoteEntity) {
        val fields = NoteFields(
            id = n.id,
            title = n.title,
            body = n.body,
            folder_id = n.folderId ?: "",
            pinned = n.pinned,
            board_position = n.boardPosition,
            folder_board_position = n.folderBoardPosition,
        )
        when {
            n.pendingDelete -> {
                if (!n.pendingCreate) deleteRemote { api.deleteNote(n.id) }
                notes.delete(n.id)
            }
            n.pendingCreate -> {
                api.createNote(NoteBody(fields))
                notes.upsert(n.copy(dirty = false, pendingCreate = false))
            }
            n.dirty -> {
                api.updateNote(n.id, NoteBody(fields.copy(id = null)))
                notes.upsert(n.copy(dirty = false))
            }
        }
    }

    private suspend fun pushFolder(f: FolderEntity) {
        when {
            f.pendingDelete -> {
                if (!f.pendingCreate) deleteRemote { api.deleteFolder(f.id) }
                folders.delete(f.id)
            }
            f.pendingCreate -> {
                api.createFolder(FolderBody(FolderFields(id = f.id, name = f.name)))
                folders.upsert(f.copy(dirty = false, pendingCreate = false))
            }
            f.dirty -> {
                api.updateFolder(f.id, FolderBody(FolderFields(name = f.name)))
                folders.upsert(f.copy(dirty = false))
            }
        }
    }

    private suspend fun deleteRemote(call: suspend () -> Unit) {
        try {
            call()
        } catch (e: HttpException) {
            if (e.code() != 404) throw e
        }
    }

    private suspend fun pull() {
        val changes = api.changes(cursor.get())
        for (f in changes.folders) {
            if (f.deleted_at != null) folders.delete(f.id)
            else folders.upsert(FolderEntity(f.id, f.name, f.position))
        }
        for (n in changes.notes) {
            val local = notes.find(n.id)
            if (local?.dirty == true || local?.pendingDelete == true) continue
            if (n.deleted_at != null || n.archived_at != null) notes.delete(n.id)
            else notes.upsert(NoteEntity(n.id, n.title, n.body, n.folder_id, n.pinned, n.board_position, n.folder_board_position, n.updated_at))
        }
        cursor.set(changes.cursor)
    }
}
