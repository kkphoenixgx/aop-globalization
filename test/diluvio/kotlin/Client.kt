import io.panteao.BdiClient
import kotlin.system.exitProcess
import kotlin.concurrent.thread

fun main() {
    println("[DILUVIO] Kotlin client starting")
    val client = BdiClient("127.0.0.1", 44444)

    thread {
        Thread.sleep(5000)
        println("[DILUVIO] TIMEOUT")
        client.close()
        exitProcess(1)
    }

    client.registerAction("send_push_notification") { args, respond ->
        println("[DILUVIO] Action handled: send_push_notification")
        respond(true)
        println("[DILUVIO] SUCCESS")
        client.close()
        exitProcess(0)
    }

    try {
        println("[DILUVIO] Connected!")
        client.sendMsg("tell", "external", "orquestrador", "evacuation_order(zone2)")
        Thread.sleep(Long.MAX_VALUE)
    } catch (e: Exception) {
        println("[DILUVIO] FAILURE: ${e.message}")
        exitProcess(1)
    }
}
