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
        private const val VERSION = "1.1.16"

        private fun downloadEngine(binPath: String) {
            val isWin = System.getProperty("os.name").lowercase().contains("win")
            val isMac = System.getProperty("os.name").lowercase().contains("mac")
            val osName = if (isWin) "win32" else if (isMac) "darwin" else "linux"
            
            val arch = System.getProperty("os.arch").lowercase()
            val archStr = if (arch.contains("arm") || arch.contains("aarch64")) "arm64" else "x64"
            
            val pkgName = "panteao-engine-$osName-$archStr"
            val urlStr = "https://registry.npmjs.org/$pkgName/-/$pkgName-$VERSION.tgz"
            
            println("\u001B[36m[Panteao]\u001B[0m Downloading native engine for $osName-$archStr (v$VERSION)...")
            
            val tmpDir = java.io.File(System.getProperty("java.io.tmpdir"))
            val tarFile = java.io.File(tmpDir, "engine-${java.util.UUID.randomUUID()}.tgz")
            
            val curlPb = ProcessBuilder(if (isWin) "C:\\Windows\\System32\\curl.exe" else "/usr/bin/curl", "-sL", "-o", tarFile.absolutePath, urlStr)
            curlPb.start().waitFor()
            
            val extractDir = java.io.File(tmpDir, "extract-${java.util.UUID.randomUUID()}")
            extractDir.mkdirs()
            
            val tarPb = ProcessBuilder(if (isWin) "C:\\Windows\\System32\\tar.exe" else "/usr/bin/tar", "-xzf", tarFile.absolutePath, "-C", extractDir.absolutePath)
            tarPb.start().waitFor()
            
            var sourcePath: java.nio.file.Path? = null
            java.nio.file.Files.walk(extractDir.toPath()).use { stream ->
                sourcePath = stream.filter { p -> p.fileName.toString() == (if (isWin) "panteao-engine.exe" else "panteao-engine") }.findFirst().orElse(null)
            }
            
            if (sourcePath != null) {
                val target = java.io.File(binPath)
                target.parentFile?.mkdirs()
                java.nio.file.Files.move(sourcePath, target.toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
                if (!isWin) {
                    target.setExecutable(true)
                }
            }
            
            tarFile.delete()
            deleteDirectory(extractDir)
        }
        
        private fun deleteDirectory(directoryToBeDeleted: java.io.File) {
            val allContents = directoryToBeDeleted.listFiles()
            if (allContents != null) {
                for (file in allContents) {
                    deleteDirectory(file)
                }
            }
            directoryToBeDeleted.delete()
        }

        private fun readLogs(inputStream: java.io.InputStream) {
            val t = Thread {
                try {
                    BufferedReader(InputStreamReader(inputStream, StandardCharsets.UTF_8)).use { reader ->
                        var line: String?
                        while (reader.readLine().also { line = it } != null) {
                            val l = line!!.trim()
                            if (l.isEmpty()) continue
                            if (l.startsWith("[") && l.contains("]")) {
                                val end = l.indexOf("]")
                                val name = l.substring(1, end)
                                val parts = name.split("\\.".toRegex())
                                val shortName = parts.last()
                                println("\u001B[36m[$shortName]\u001B[0m ${l.substring(end + 1).trim()}")
                            } else {
                                println("\u001B[36m[MAS]\u001B[0m $l")
                            }
                        }
                    }
                } catch (e: Exception) {}
            }
            t.isDaemon = true
            t.start()
        }

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
            var bin = findBinary()
            if (bin == "panteao-engine" || bin == "panteao-engine.exe") {
                val isWin = System.getProperty("os.name").lowercase().contains("win")
                bin = System.getProperty("user.dir") + "/" + (if (isWin) "panteao-engine.exe" else "panteao-engine")
                if (!java.io.File(bin).exists()) {
                    downloadEngine(bin)
                }
            }
            val pb = ProcessBuilder(bin, project, "--port", actualPort.toString())
            pb.redirectOutput(ProcessBuilder.Redirect.PIPE)
            pb.redirectError(ProcessBuilder.Redirect.PIPE)
            engineProcess = pb.start()
            engineProcess?.let {
                readLogs(it.inputStream)
                readLogs(it.errorStream)
            }
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
