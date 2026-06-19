package io.panteao

import java.io.BufferedReader
import java.io.Closeable
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import org.json.JSONObject

class BdiClient(host: String, port: Int) : Closeable {

    private val socket = Socket(host, port)
    private val out = PrintWriter(socket.getOutputStream().writer(StandardCharsets.UTF_8), true)
    private val reader = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))
    private val actionHandlers = ConcurrentHashMap<String, (Array<String>, (Boolean) -> Unit) -> Unit>()
    private val listenerThread: Thread
    @Volatile private var running = true

    init {
        listenerThread = Thread { listen() }
        listenerThread.isDaemon = true
        listenerThread.start()
    }

    private fun listen() {
        try {
            var line: String?
            while (running) {
                line = reader.readLine()
                if (line == null) break
                handleIncomingLine(line.trim())
            }
        } catch (e: Exception) {
            // connection closed
        }
    }

    private fun handleIncomingLine(line: String) {
        if (line.isEmpty()) return
        try {
            val msg = JSONObject(line)
            if (msg.optString("type") == "action") {
                val rawAction = msg.optString("action", "")
                val (name, args) = parseAction(rawAction)
                val handler = actionHandlers[name]
                if (handler != null) {
                    val actionId = msg.optString("id")
                    handler(args) { success -> sendActionResult(actionId, success) }
                } else {
                    sendActionResult(msg.optString("id"), true)
                }
            }
        } catch (e: Exception) {
            // ignore parse errors
        }
    }

    private fun parseAction(actionStr: String): Pair<String, Array<String>> {
        val parenIdx = actionStr.indexOf('(')
        if (parenIdx == -1) {
            return Pair(actionStr.trim(), emptyArray())
        }

        val name = actionStr.substring(0, parenIdx).trim()
        val argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'))
        
        val argsList = mutableListOf<String>()
        val current = StringBuilder()
        var insideQuotes = false

        for (i in 0 until argsStr.length) {
            val c = argsStr[i]
            if (c == '"') {
                insideQuotes = !insideQuotes
            } else if (c == ',' && !insideQuotes) {
                argsList.add(cleanArg(current.toString()))
                current.setLength(0)
            } else {
                current.append(c)
            }
        }
        if (current.isNotEmpty()) {
            argsList.add(cleanArg(current.toString()))
        }

        return Pair(name, argsList.toTypedArray())
    }

    private fun cleanArg(arg: String): String {
        return arg.trim().replace("^\"|\"$".toRegex(), "")
    }

    fun sendPerception(action: String, perception: String) {
        val payload = JSONObject().apply {
            put("type", "perception")
            put("action", action)
            put("perception", perception)
        }
        out.println(payload.toString())
    }

    fun registerAction(actionName: String, handler: (args: Array<String>, respond: (Boolean) -> Unit) -> Unit) {
        actionHandlers[actionName] = handler
    }

    private fun sendActionResult(id: String, success: Boolean) {
        val payload = JSONObject().apply {
            put("type", "action_result")
            put("id", id)
            put("success", success)
        }
        out.println(payload.toString())
    }

    override fun close() {
        running = false
        reader.close()
        out.close()
        socket.close()
    }
}
