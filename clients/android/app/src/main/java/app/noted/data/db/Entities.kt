package app.noted.data.db

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
)
