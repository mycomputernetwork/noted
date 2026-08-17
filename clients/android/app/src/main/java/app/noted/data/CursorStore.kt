package app.noted.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.dataStore by preferencesDataStore("sync")

class CursorStore(private val context: Context) {
    private val key = stringPreferencesKey("cursor")

    suspend fun get(): String? = context.dataStore.data.first()[key]

    suspend fun set(value: String) {
        context.dataStore.edit { it[key] = value }
    }
}
