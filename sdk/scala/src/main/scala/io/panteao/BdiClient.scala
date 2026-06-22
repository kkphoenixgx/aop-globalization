package io.panteao

import java.io.{BufferedReader, InputStreamReader, PrintWriter}
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import scala.collection.mutable.ListBuffer

private[panteao] case class ParsedAction(name: String, args: Array[String])

class BdiClient(host: String, port: Int, project: String = null) extends AutoCloseable {

  private var engineProcess: Process = null
  private var actualPort = port
  private val actualHost = if (host == null || host.isEmpty) "127.0.0.1" else host

  if (project != null && !project.isEmpty) {
    if (actualPort == 0) {
      actualPort = BdiClient.getFreePort()
    }
    val bin = BdiClient.findBinary()
    val pb = new ProcessBuilder(bin, project, "--port", actualPort.toString)
    pb.redirectOutput(ProcessBuilder.Redirect.DISCARD)
    pb.redirectError(ProcessBuilder.Redirect.DISCARD)
    engineProcess = pb.start()
    Thread.sleep(800)
  } else {
    if (actualPort == 0) actualPort = 44444
  }

  private val socket = new Socket(actualHost, actualPort)
  private val out = new PrintWriter(new java.io.OutputStreamWriter(socket.getOutputStream, StandardCharsets.UTF_8), true)
  private val reader = new BufferedReader(new InputStreamReader(socket.getInputStream, StandardCharsets.UTF_8))

  {
    var handshakeCompleted = false
    while (!handshakeCompleted) {
      val line = reader.readLine()
      if (line == null) throw new java.io.IOException("Connection lost during handshake")
      if (line.contains("\"type\":\"mas_ready\"")) {
        handshakeCompleted = true
      }
    }
  }

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
    if (line.trim.isEmpty) return
    try {
      if (line.contains("\"type\":\"action\"")) {
        val actionIdPattern = "\"id\":\"(.*?)\"".r
        val actionPattern = "\"action\":\"(.*?)\"".r
        val actionId = actionIdPattern.findFirstMatchIn(line).map(_.group(1)).getOrElse("")
        val rawAction = actionPattern.findFirstMatchIn(line).map(_.group(1)).getOrElse("")
        val (name, args) = parseAction(rawAction)
        val handler = actionHandlers.get(name)
        if (handler != null) {
          handler(args, (success: Boolean) => sendActionResult(actionId, success))
        } else {
          sendActionResult(actionId, true)
        }
      }
    } catch {
      case _: Exception => // ignore parse errors
    }
  }


  private def parseAction(actionStr: String): (String, Array[String]) = {
    val parenIdx = actionStr.indexOf('(')
    if (parenIdx == -1) {
      return (actionStr.trim, Array.empty[String])
    }

    val name = actionStr.substring(0, parenIdx).trim
    val argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'))
    
    val argsList = new ListBuffer[String]()
    val current = new StringBuilder()
    var insideQuotes = false
    var depthBrackets = 0
    var depthParens = 0

    for (i <- 0 until argsStr.length) {
      val c = argsStr.charAt(i)
      if (c == '"') {
        insideQuotes = !insideQuotes
        current.append(c)
      } else if (!insideQuotes && c == '[') {
        depthBrackets += 1
        current.append(c)
      } else if (!insideQuotes && c == ']') {
        depthBrackets -= 1
        current.append(c)
      } else if (!insideQuotes && c == '(') {
        depthParens += 1
        current.append(c)
      } else if (!insideQuotes && c == ')') {
        depthParens -= 1
        current.append(c)
      } else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
        argsList.append(cleanArg(current.toString()))
        current.setLength(0)
      } else {
        current.append(c)
      }
    }
    if (current.nonEmpty) {
      argsList.append(cleanArg(current.toString()))
    }

    (name, argsList.toArray)
  }

  private def cleanArg(arg: String): String = {
    val s = arg.trim
    if (s.startsWith("\"") && s.endsWith("\"") && s.length >= 2) {
      s.substring(1, s.length - 1)
    } else {
      s
    }
  }

  def sendMsg(performative: String, sender: String, receiver: String, content: String): Unit = {
    val json = "{\"type\":\"message\",\"performative\":\"" + performative + "\",\"sender\":\"" + sender + "\",\"receiver\":\"" + receiver + "\",\"content\":\"" + content + "\"}\n"
    out.print(json)
    out.flush()
  }

  def sendPerception(action: String, perception: String): Unit = {
    val json = "{\"type\":\"perception\",\"action\":\"" + action + "\",\"perception\":\"" + perception + "\"}"
    out.println(json)
  }

  def registerAction(actionName: String, handler: (Array[String], (Boolean) => Unit) => Unit): Unit = {
    actionHandlers.put(actionName, handler)
  }

  private def sendActionResult(id: String, success: Boolean): Unit = {
    val json = "{\"type\":\"action_result\",\"id\":\"" + id + "\",\"success\":" + success + "}"
    out.println(json)
  }

  override def close(): Unit = {
    running = false
    try { reader.close() } catch { case _: Exception => }
    try { out.close() } catch { case _: Exception => }
    try { socket.close() } catch { case _: Exception => }
    try { if (engineProcess != null) engineProcess.destroy() } catch { case _: Exception => }
  }
}

object BdiClient {
  private def getFreePort(): Int = {
    val s = new java.net.ServerSocket(0)
    val p = s.getLocalPort
    s.close()
    p
  }

  private def findBinary(): String = {
    val isWin = System.getProperty("os.name").toLowerCase.contains("win")
    val binName = if (isWin) "panteao-engine.exe" else "panteao-engine"
    val userDir = System.getProperty("user.dir")
    if (userDir != null) {
      val cand1 = new java.io.File(userDir, binName)
      if (cand1.exists()) return cand1.getAbsolutePath
      val cand2 = new java.io.File(userDir, s"bin/$binName")
      if (cand2.exists()) return cand2.getAbsolutePath
    }
    binName
  }
}
