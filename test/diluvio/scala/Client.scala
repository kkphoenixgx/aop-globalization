// ============================================================================
// Operação Dilúvio — O Analisador de Correntes (Scala)
//
// Scala simulates big data soil analysis.
// Sends a soil_saturation_critical percept and handles evacuate_zone actions.
// ============================================================================

import java.io.{BufferedReader, InputStreamReader, PrintWriter}
import java.net.Socket
import scala.util.{Try, Using}

object Client {

  val Host      = "127.0.0.1"
  val Port      = 44444
  val TimeoutMs = 5000
  val StartupDelayMs = 1000

  val Perception: String =
    """{"type":"perception","action":"add","perception":"soil_saturation_critical(zona_b)"}"""

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  def nowNs(): Long = System.nanoTime()

  def elapsedMs(startNs: Long): Double =
    (System.nanoTime() - startNs) / 1e6

  def log(msg: String): Unit =
    println(s"[DILUVIO] $msg")

  def jsonField(json: String, field: String): Option[String] = {
    val key = s""""$field""""
    val idx = json.indexOf(key)
    if (idx == -1) None
    else {
      val afterKey = json.substring(idx + key.length)
      val colonIdx = afterKey.indexOf(":")
      if (colonIdx == -1) None
      else {
        val nextQuote = afterKey.indexOf("\"", colonIdx)
        if (nextQuote != -1 && (nextQuote - colonIdx) < 5) {
          val endQuote = afterKey.indexOf("\"", nextQuote + 1)
          if (endQuote != -1) Some(afterKey.substring(nextQuote + 1, endQuote))
          else None
        } else {
          val commaIdx = afterKey.indexOf(",", colonIdx)
          val braceIdx = afterKey.indexOf("}", colonIdx)
          val endIdx = if (commaIdx == -1 && braceIdx == -1) afterKey.length
                       else if (commaIdx == -1) braceIdx
                       else if (braceIdx == -1) commaIdx
                       else math.min(commaIdx, braceIdx)
          Some(afterKey.substring(colonIdx + 1, endIdx).trim)
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Main
  // ---------------------------------------------------------------------------

  def main(args: Array[String]): Unit = {
    val t0 = nowNs()
    log("O Analisador de Correntes — Scala test starting")

    // Wait for engine readiness
    log(s"Waiting ${StartupDelayMs}ms for engine readiness...")
    Thread.sleep(StartupDelayMs)

    val tConnect = nowNs()

    var socket: Socket = null
    var actionHandled = false

    try {
      socket = new Socket(Host, Port)
      socket.setSoTimeout(TimeoutMs)
      val connMs = elapsedMs(tConnect)
      log(f"Connected to engine at $Host:$Port ($connMs%.2fms)")

      val out = new PrintWriter(new java.io.OutputStreamWriter(socket.getOutputStream, java.nio.charset.StandardCharsets.UTF_8), true)
      val in  = new BufferedReader(new java.io.InputStreamReader(socket.getInputStream, java.nio.charset.StandardCharsets.UTF_8))

      // Send perception
      val tSend = nowNs()
      out.println(Perception)
      val sendMs = elapsedMs(tSend)
      log(f"Perception sent: soil_saturation_critical(zona_b) ($sendMs%.2fms)")

      // Read lines looking for action requests
      var line = in.readLine()
      while (line != null && !actionHandled) {
        val trimmed = line.trim
        if (trimmed.nonEmpty) {
          log(s"Received: $trimmed")

          val msgType = jsonField(trimmed, "type")
          val action  = jsonField(trimmed, "action")
          val id      = jsonField(trimmed, "id")
          val agent   = jsonField(trimmed, "agent")

          if (msgType.contains("action") && action.exists(_.startsWith("evacuate_zone"))) {
            actionHandled = true
            val tAction = nowNs()

            val response = s"""{"type":"action_result","id":"${id.getOrElse("")}","success":true}"""
            out.println(response)
            val actionMs = elapsedMs(tAction)

            log(s"Action handled: ${action.getOrElse("unknown")}")
            log(s"  Agent : ${agent.getOrElse("unknown")}")
            log(s"  ID    : ${id.getOrElse("unknown")}")
            log(f"  Response sent ($actionMs%.2fms)")

            // Print final metrics
            val totalMs = elapsedMs(t0)
            log("--- Timing Metrics ---")
            log(f"  Total elapsed    : $totalMs%.2fms")
            log(f"  Connection time  : ${elapsedMs(tConnect)}%.2fms")
            log(f"  Action round-trip: $actionMs%.2fms")
            log("--- Test Complete ---")
            log("[DILUVIO] SUCCESS")
          }
        }
        if (!actionHandled) {
          line = in.readLine()
        }
      }

      if (!actionHandled) {
        log("Connection closed before action was handled")
        log("[DILUVIO] FAILURE")
        System.exit(1)
      }

    } catch {
      case e: java.net.SocketTimeoutException =>
        log("TIMEOUT — test exceeded 5s")
        log("[DILUVIO] FAILURE")
        System.exit(1)
      case e: Exception =>
        log(s"Socket error: ${e.getMessage}")
        log("[DILUVIO] FAILURE")
        System.exit(1)
    } finally {
      if (socket != null) {
        Try(socket.close())
      }
    }

    System.exit(0)
  }
}
