package app.noted.data.api

import android.util.Log
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject

/**
 * Speaks the Action Cable WebSocket protocol just enough to subscribe to
 * SyncChannel and emit a Unit on every broadcast (the "nudge" to sync changes).
 */
class CableClient(baseUrl: String) {
    private val wsUrl = baseUrl
        .replace("http://", "ws://")
        .replace("https://", "wss://")
        .trimEnd('/') + "/cable"

    private val client = OkHttpClient()

    fun nudges(): Flow<Unit> = callbackFlow {
        val request = Request.Builder().url(wsUrl).build()

        val ws = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                val subscribe = JSONObject().apply {
                    put("command", "subscribe")
                    put("identifier", JSONObject().put("channel", "SyncChannel").toString())
                }
                webSocket.send(subscribe.toString())
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val msg = JSONObject(text)
                when (msg.optString("type")) {
                    "welcome", "confirm_subscription", "ping" -> {}
                    else -> {
                        if (msg.has("message")) {
                            trySend(Unit)
                        }
                    }
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e("CableClient", "WebSocket failure", t)
                close()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                close()
            }
        })

        awaitClose { ws.close(1000, "app backgrounded") }
    }
}
