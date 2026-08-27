package app.noted.data.api

import app.noted.BuildConfig
import app.noted.data.auth.AuthManager
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory

class Network(authManager: AuthManager) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }

    val api: NotedApi = Retrofit.Builder()
        .baseUrl(BuildConfig.BASE_URL)
        .client(
            OkHttpClient.Builder()
                .addInterceptor(BearerInterceptor(authManager))
                .apply {
                    if (BuildConfig.DEBUG) {
                        addInterceptor(HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY })
                    }
                }
                .build()
        )
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()
        .create(NotedApi::class.java)
}

/** Interceptors run off the main thread, so blocking on a refresh is fine. */
private class BearerInterceptor(private val authManager: AuthManager) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        // The session call brings its own ID token.
        if (request.header("Authorization") != null) return chain.proceed(request)

        val token = runBlocking { authManager.freshAccessToken() } ?: return chain.proceed(request)

        return chain.proceed(request.newBuilder().header("Authorization", "Bearer $token").build())
    }
}
