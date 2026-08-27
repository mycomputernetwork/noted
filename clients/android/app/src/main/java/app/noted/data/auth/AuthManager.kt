package app.noted.data.auth

import android.content.Context
import android.content.Intent
import android.net.Uri
import app.noted.BuildConfig
import app.noted.data.api.UserDto
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import net.openid.appauth.AppAuthConfiguration
import net.openid.appauth.AuthState
import net.openid.appauth.AuthorizationException
import net.openid.appauth.AuthorizationRequest
import net.openid.appauth.AuthorizationResponse
import net.openid.appauth.AuthorizationService
import net.openid.appauth.AuthorizationServiceConfiguration
import net.openid.appauth.EndSessionRequest
import net.openid.appauth.ResponseTypeValues
import net.openid.appauth.connectivity.ConnectionBuilder
import net.openid.appauth.connectivity.DefaultConnectionBuilder
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request

/** PKCE against auth, with no client secret: an APK cannot keep one. */
class AuthManager(context: Context) {
    private val service = AuthorizationService(
        context.applicationContext,
        AppAuthConfiguration.Builder().setConnectionBuilder(connectionBuilder()).build(),
    )
    private val store = SecureStore(context)
    private val json = Json { ignoreUnknownKeys = true }

    private val config = AuthorizationServiceConfiguration(
        Uri.parse("${BuildConfig.AUTH_ISSUER}/oauth/authorize"),
        Uri.parse("${BuildConfig.AUTH_ISSUER}/oauth/token"),
        null,
        Uri.parse("${BuildConfig.AUTH_ISSUER}/oauth/logout"),
    )

    private var state: AuthState = store.get(STATE)
        ?.let { runCatching { AuthState.jsonDeserialize(it) }.getOrNull() }
        ?: AuthState()

    /** Whose notes the local cache holds. Outlives the tokens, so a re-sign-in keeps the cache. */
    var account: UserDto? = store.get(ACCOUNT)?.let { runCatching { json.decodeFromString<UserDto>(it) }.getOrNull() }
        set(value) {
            field = value
            value?.let { store.put(ACCOUNT, json.encodeToString(UserDto.serializer(), it)) } ?: store.remove(ACCOUNT)
        }

    val idToken: String? get() = state.idToken

    fun isSignedIn(): Boolean = state.isAuthorized

    fun signInIntent(): Intent = service.getAuthorizationRequestIntent(
        AuthorizationRequest.Builder(config, BuildConfig.AUTH_CLIENT_ID, ResponseTypeValues.CODE, Uri.parse(BuildConfig.AUTH_REDIRECT_URI))
            .setScope(SCOPE)
            .build()
    )

    suspend fun exchange(intent: Intent): Result<Unit> {
        val response = AuthorizationResponse.fromIntent(intent)
            ?: return Result.failure(AuthorizationException.fromIntent(intent) ?: AuthorizationException.GeneralErrors.SERVER_ERROR)

        return suspendCancellableCoroutine { continuation ->
            service.performTokenRequest(response.createTokenExchangeRequest()) { tokens, exception ->
                state.update(response, null)
                state.update(tokens, exception)
                if (tokens != null) persist() else forget()
                continuation.resume(if (tokens != null) Result.success(Unit) else Result.failure(exception!!))
            }
        }
    }

    /** Refreshes ahead of expiry rather than on a 401. */
    suspend fun freshAccessToken(): String? = suspendCancellableCoroutine { continuation ->
        state.performActionWithFreshTokens(service) { accessToken, _, exception ->
            when {
                exception == null -> persist()
                // Revoked or rotated past. Every other failure is the network,
                // and a signal lost in a lift must not sign anyone out.
                exception.type == AuthorizationException.TYPE_OAUTH_TOKEN_ERROR -> forget()
            }
            continuation.resume(accessToken)
        }
    }

    /**
     * Clearing the tokens leaves auth's cookie in the browser, and one tap gets
     * back in. The web app hands over to the same endpoint on sign-out.
     */
    fun signOutIntent(): Intent? = state.idToken?.let { idToken ->
        service.getEndSessionRequestIntent(
            EndSessionRequest.Builder(config)
                .setIdTokenHint(idToken)
                .setPostLogoutRedirectUri(Uri.parse(BuildConfig.AUTH_LOGOUT_URI))
                .build()
        )
    }

    suspend fun signOut() {
        revoke(state.refreshToken)
        forget()
        account = null
    }

    fun close() = service.dispose()

    private suspend fun revoke(token: String?) {
        if (token == null) return

        withContext(Dispatchers.IO) {
            runCatching {
                OkHttpClient().newCall(
                    Request.Builder()
                        .url("${BuildConfig.AUTH_ISSUER}/oauth/revoke")
                        .post(FormBody.Builder().add("token", token).add("client_id", BuildConfig.AUTH_CLIENT_ID).build())
                        .build()
                ).execute().close()
            }
        }
    }

    private fun persist() = store.put(STATE, state.jsonSerializeString())

    private fun forget() {
        state = AuthState()
        store.remove(STATE)
    }

    private companion object {
        const val SCOPE = "openid email profile offline_access"
        const val STATE = "state"
        const val ACCOUNT = "account"

        // AppAuth refuses cleartext and throws on its own background thread,
        // which is a crash rather than a failed sign-in. auth is http on
        // localhost in development and https everywhere else.
        fun connectionBuilder(): ConnectionBuilder =
            if (BuildConfig.DEBUG) LocalhostConnectionBuilder else DefaultConnectionBuilder.INSTANCE
    }
}

private object LocalhostConnectionBuilder : ConnectionBuilder {
    override fun openConnection(uri: Uri): HttpURLConnection =
        (URL(uri.toString()).openConnection() as HttpURLConnection).apply {
            connectTimeout = TimeUnit.SECONDS.toMillis(15).toInt()
            readTimeout = TimeUnit.SECONDS.toMillis(10).toInt()
            instanceFollowRedirects = false
        }
}
