package io.panteao

import java.io.BufferedReader
import java.io.Closeable
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap

class BdiClient(host: String, port: Int, project: String? = null) : Closeable {

    private val socket: Socket
    private val out: PrintWriter
    private val reader: BufferedReader
    private val actionHandlers = ConcurrentHashMap<String, (Array<String>, (Boolean) -> Unit) -> Unit>()
    private val listenerThread: Thread
    @Volatile private var running = true
    private var engineProcess: Process? = null

    companion object {
        private fun getFreePort(): Int {
            java.net.ServerSocket(0).use { return it.localPort }
        }

        private fun findBinary(): String {
            val isWin = System.getProperty("os.name").lowercase().contains("win")
            val binName = if (isWin) "panteao-engine.exe" else "panteao-engine"
            val userDir = System.getProperty("user.dir")
            if (userDir != null) {
                val cand1 = java.io.File(userDir, binName)
                if (cand1.exists()) return cand1.absolutePath
                val cand2 = java.io.File(userDir, "bin/$binName")
                if (cand2.exists()) return cand2.absolutePath
            }
            return binName
        }
    }

    init {
        var actualPort = port
        val actualHost = if (host.isEmpty()) "127.0.0.1" else host
        if (project != null && project.isNotEmpty()) {
            if (actualPort == 0) {
                actualPort = getFreePort()
            }
            val bin = findBinary()
            val pb = ProcessBuilder(bin, project, "--port", actualPort.toString())
            pb.redirectOutput(ProcessBuilder.Redirect.DISCARD)
            pb.redirectError(ProcessBuilder.Redirect.DISCARD)
            engineProcess = pb.start()
            Thread.sleep(800)
        } else {
            engineProcess = null
            if (actualPort == 0) actualPort = 44444
        }

        socket = Socket(actualHost, actualPort)
        out = PrintWriter(socket.getOutputStream().writer(StandardCharsets.UTF_8), true)
        reader = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))

        while (true) {
            val line = reader.readLine() ?: throw java.io.IOException("Connection lost during handshake")
            if (line.contains("\"type\":\"mas_ready\"")) {
                break
            }
        }

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
        }
    }

    private fun handleIncomingLine(line: String) {
        if (line.isEmpty()) return
        try {
            if (line.contains("\"type\":\"action\"")) {
                val idStart = line.indexOf("\"id\":\"")
                val actionId = if (idStart != -1) {
                    val start = idStart + 6
                    val end = line.indexOf("\"", start)
                    line.substring(start, end)
                } else ""
                
                val actionStart = line.indexOf("\"action\":\"")
                val rawAction = if (actionStart != -1) {
                    val start = actionStart + 10
                    // action value ends right before the closing brace or the next comma
                    val end = line.lastIndexOf("\"")
                    var s = line.substring(start, end)
                    if (s.endsWith("\"}")) s = s.substring(0, s.length - 2)
                    if (s.endsWith("\"")) s = s.substring(0, s.length - 1)
                    s = s.replace("\\\"", "\"")
                    s
                } else ""

                val (name, args) = parseAction(rawAction)
                val handler = actionHandlers[name]
                if (handler != null) {
                    handler(args) { success -> sendActionResult(actionId, success) }
                } else {
                    sendActionResult(actionId, true)
                }
            }
        } catch (e: Exception) {
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
        var depthBrackets = 0
        var depthParens = 0

        for (i in 0 until argsStr.length) {
            val c = argsStr[i]
            if (c == '"') {
                insideQuotes = !insideQuotes
                current.append(c)
            } else if (!insideQuotes && c == '[') {
                depthBrackets++
                current.append(c)
            } else if (!insideQuotes && c == ']') {
                depthBrackets--
                current.append(c)
            } else if (!insideQuotes && c == '(') {
                depthParens++
                current.append(c)
            } else if (!insideQuotes && c == ')') {
                depthParens--
                current.append(c)
            } else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
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
        val s = arg.trim()
        if (s.startsWith("\"") && s.endsWith("\"") && s.length >= 2) {
            return s.substring(1, s.length - 1)
        }
        return s
    }

        fun sendMsg(performative: String, sender: String, receiver: String, content: String) {
        val json = "{\"type\":\"message\",\"performative\":\"$performative\",\"sender\":\"$sender\",\"receiver\":\"$receiver\",\"content\":\"$content\"}\n"
        out.print(json)
        out.flush()
    }

    fun sendPerception(action: String, perception: String) {
        val json = "{\"type\":\"perception\",\"action\":\"$action\",\"perception\":\"$perception\"}\n"
        out.print(json)
        out.flush()
    }

    fun registerAction(actionName: String, handler: (args: Array<String>, respond: (Boolean) -> Unit) -> Unit) {
        actionHandlers[actionName] = handler
    }

    private fun sendActionResult(id: String, success: Boolean) {
        val json = "{\"type\":\"action_result\",\"id\":\"$id\",\"success\":$success}\n"
        out.print(json)
        out.flush()
    }

    override fun close() {
        running = false
        try { reader.close() } catch (e: Exception) {}
        try { out.close() } catch (e: Exception) {}
        try { socket.close() } catch (e: Exception) {}
        try { engineProcess?.destroy() } catch (e: Exception) {}
    }
}
