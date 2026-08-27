package app.noted.data.api

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface NotedApi {
    // The ID token, not the access token: only it carries an email.
    @POST("api/v1/session")
    suspend fun session(@Header("Authorization") authorization: String): UserDto

    @GET("api/v1/changes")
    suspend fun changes(@Query("cursor") cursor: String?): ChangesDto

    @POST("api/v1/notes")
    suspend fun createNote(@Body body: NoteBody): NoteDto

    @PATCH("api/v1/notes/{id}")
    suspend fun updateNote(@Path("id") id: String, @Body body: NoteBody): NoteDto

    @DELETE("api/v1/notes/{id}")
    suspend fun deleteNote(@Path("id") id: String)

    @POST("api/v1/folders")
    suspend fun createFolder(@Body body: FolderBody): FolderDto

    @PATCH("api/v1/folders/{id}")
    suspend fun updateFolder(@Path("id") id: String, @Body body: FolderBody): FolderDto

    @DELETE("api/v1/folders/{id}")
    suspend fun deleteFolder(@Path("id") id: String)
}
