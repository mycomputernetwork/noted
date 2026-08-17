package app.noted.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface NoteDao {
    @Query("SELECT * FROM notes WHERE deleted = 0 AND pendingDelete = 0 ORDER BY pinned DESC, updatedAt DESC")
    fun observe(): Flow<List<NoteEntity>>

    @Query("SELECT * FROM notes WHERE id = :id")
    suspend fun find(id: String): NoteEntity?

    @Query("SELECT * FROM notes WHERE dirty = 1 OR pendingCreate = 1 OR pendingDelete = 1")
    suspend fun pending(): List<NoteEntity>

    @Upsert
    suspend fun upsert(note: NoteEntity)

    @Query("DELETE FROM notes WHERE id = :id")
    suspend fun delete(id: String)
}

@Dao
interface FolderDao {
    @Query("SELECT * FROM folders WHERE deleted = 0 AND pendingDelete = 0 ORDER BY position")
    fun observe(): Flow<List<FolderEntity>>

    @Query("SELECT * FROM folders WHERE dirty = 1 OR pendingCreate = 1 OR pendingDelete = 1")
    suspend fun pending(): List<FolderEntity>

    @Upsert
    suspend fun upsert(folder: FolderEntity)

    @Query("DELETE FROM folders WHERE id = :id")
    suspend fun delete(id: String)
}
