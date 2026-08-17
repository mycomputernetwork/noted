package app.noted.data.api

import kotlinx.serialization.Serializable

@Serializable
data class NoteDto(
    val id: String,
    val title: String? = null,
    val body: String? = null,
    val folder_id: String? = null,
    val pinned: Boolean = false,
    val position: Int? = null,
    val empty: Boolean = false,
    val archived_at: String? = null,
    val deleted_at: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
)

@Serializable
data class FolderDto(
    val id: String,
    val name: String,
    val position: Int = 0,
    val deleted_at: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null,
)

@Serializable
data class ChangesDto(
    val notes: List<NoteDto> = emptyList(),
    val folders: List<FolderDto> = emptyList(),
    val cursor: String,
)

@Serializable
data class NoteBody(val note: NoteFields)

@Serializable
data class NoteFields(
    val id: String? = null,
    val title: String? = null,
    val body: String? = null,
    val folder_id: String? = null,
    val pinned: Boolean? = null,
)

@Serializable
data class FolderBody(val folder: FolderFields)

@Serializable
data class FolderFields(val id: String? = null, val name: String? = null)
