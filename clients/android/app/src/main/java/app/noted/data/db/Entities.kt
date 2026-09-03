package app.noted.data.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "notes")
data class NoteEntity(
    @PrimaryKey val id: String,
    val title: String?,
    val body: String?,
    val folderId: String?,
    val pinned: Boolean,
    val boardPosition: Int?,
    val folderBoardPosition: Int?,
    val updatedAt: String?,
    val dirty: Boolean = false,
    val pendingCreate: Boolean = false,
    val pendingDelete: Boolean = false,
    val deleted: Boolean = false,
    // Bumped by every local edit. A push clears dirty only if it is unchanged,
    // so an edit made during the request is not cleared along with the one sent.
    @ColumnInfo(defaultValue = "0") val revision: Int = 0,
)

@Entity(tableName = "folders")
data class FolderEntity(
    @PrimaryKey val id: String,
    val name: String,
    val position: Int,
    val dirty: Boolean = false,
    val pendingCreate: Boolean = false,
    val pendingDelete: Boolean = false,
    val deleted: Boolean = false,
    @ColumnInfo(defaultValue = "0") val revision: Int = 0,
)
