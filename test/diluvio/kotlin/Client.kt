import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.Socket

fun main() {
    val host = "127.0.0.1"
    val port = 44444
    val timeoutMs = 5000L
    val start = System.currentTimeMillis()

    println("[DILUVIO] Kotlin client starting")
    try {
        val socket = Socket(host, port)
        socket.soTimeout = 5000
        val out = PrintWriter(socket.getOutputStream(), true)
        val reader = BufferedReader(InputStreamReader(socket.getInputStream()))

        println("[DILUVIO] Connected in ${System.currentTimeMillis() - start}ms")

        // Wait 1s
        Thread.sleep(1000)

        // Send perception
        val percept = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"evacuation_order(centro)\"}"
        println("[DILUVIO] Sending: $percept")
        out.println(percept)

        // Read response
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            println("[DILUVIO] Received: $line")
            if (line!!.contains("\"type\":\"action\"")) {
                // Parse action ID
                val idPattern = "\"id\":\"([^\"]+)\"".toRegex()
                val match = idPattern.find(line!!)
                val id = match?.groupValues?.get(1) ?: ""

                val response = "{\"type\":\"action_result\",\"id\":\"$id\",\"success\":true}"
                println("[DILUVIO] Sending result: $response")
                out.println(response)

                println("[DILUVIO] SUCCESS")
                break
            }
        }
        socket.close()
    } catch (e: Exception) {
        println("[DILUVIO] FAILURE: ${e.message}")
        System.exit(1)
    }
}
