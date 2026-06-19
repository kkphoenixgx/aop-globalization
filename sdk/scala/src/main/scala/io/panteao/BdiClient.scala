package io.panteao

import java.io.{BufferedReader, InputStreamReader, PrintWriter}
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import org.json.JSONObject

class BdiClient(host: String, port: Int) extends AutoCloseable {

  private val socket = new Socket(host, port)
  private val out = new PrintWriter(new java.io.OutputStreamWriter(socket.getOutputStream, StandardCharsets.UTF_8), true)
  private val reader = new BufferedReader(new InputStreamReader(socket.getInputStream, StandardCharsets.UTF_8))
  private val actionHandlers = new ConcurrentHashMap[String, (Array[String], (Boolean) => Unit) => Unit]()
  private val listenerThread = new Thread(new Runnable {
    override def run(): Unit = listen()
  })
  @volatile private var running = true

  listenerThread.setDaemon(true)
  listenerThread.start()

  private def listen(): Unit = {
    try {
      var line = reader.readLine()
      while (running && line != null) {
        handleIncomingLine(line.trim)
        line = reader.readLine()
      }
    } catch {
      case _: Exception => // connection closed
    }
  }

  private def handleIncomingLine(line: String): Unit = {
    if (line.isEmpty) return
    try {
      val msg = new JSONObject(line)
      if ("action" == msg.optString("type")) {
        val rawAction = msg.optString("action", "")
        val parsed = parseAction(rawAction)
        val handler = actionHandlers.get(parsed.name)
        if (handler != null) {
          val actionId = msg.optString("id")
          handler(parsed.args, (success: Boolean) => sendActionResult(actionId, success))
        } else {
          sendActionResult(msg.optString("id"), true)
        }
      }
    } catch {
      case _: Exception => // ignore json parse errors
    }
  }

  private case class ParsedAction(name: String, args: Array[String])

  private def parseAction(actionStr: String): ParsedAction = {
    val parenIdx = actionStr.indexOf('(')
    if (parenIdx == -1) {
      return ParsedAction(actionStr.trim, Array.empty)
    }

    val name = actionStr.substring(0, parenIdx).trim
    val argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'))
    
    val argsList = mutableList()
    val current = new StringBuilder()
    var insideQuotes = false

    for (i <- 0 until argsStr.length) {
      val c = argsStr.charAt(i)
      if (c == '"') {
        insideQuotes = !insideQuotes
      } else if (c == ',' && !insideQuotes) {
        argsList.append(cleanArg(current.toString()))
        current.setLength(0)
      } else {
        current.append(c)
      }
    }
    if (current.nonEmpty) {
      argsList.append(cleanArg(current.toString()))
    }

    ParsedAction(name, argsList.toArray)
  }

  private def cleanArg(arg: String): String = {
    arg.trim.replaceAll("^\"|\"$", "")
  }

  private def mutableList(): scala.collection.mutable.ListBuffer[String] = {
    new scala.collection.mutable.ListBuffer[String]()
  }

  def sendPerception(action: String, perception: String): Unit = {
    val payload = new JSONObject()
    payload.put("type", "perception")
    payload.put("action", action)
    payload.put("perception", perception)
    out.println(payload.toString)
  }

  def registerAction(actionName: String, handler: (Array[String], (Boolean) => Unit) => Unit): Unit = {
    actionHandlers.put(actionName, handler)
  }

  private def sendActionResult(id: String, success: Boolean): Unit = {
    val payload = new JSONObject()
    payload.put("type", "action_result")
    payload.put("id", id)
    payload.put("success", success)
    out.println(payload.toString)
  }

  override def close(): Unit = {
    running = false
    reader.close()
    out.close()
    socket.close()
  }
}
