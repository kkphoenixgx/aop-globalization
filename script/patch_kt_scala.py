import os
import re

def patch_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Remove import
    content = re.sub(r'import org\.json\.JSONObject\n?', '', content)
    
    # Patch sendPerception
    content = re.sub(
        r'val payload = JSONObject\(\)\.apply \{[^}]+\}\s*out\.println\(payload\.toString\(\)\)',
        r'val json = "{\\"type\\":\\"perception\\",\\"action\\":\\"$action\\",\\"perception\\":\\"$perception\\"}\\n"\n        out.print(json)\n        out.flush()',
        content, flags=re.MULTILINE
    )
    # Scala version
    content = re.sub(
        r'val payload = new JSONObject\(\)\s*payload\.put\("type", "perception"\)\s*payload\.put\("action", action\)\s*payload\.put\("perception", perception\)\s*out\.println\(payload\.toString\(\)\)',
        r'val json = s"{\\"type\\":\\"perception\\",\\"action\\":\\"$action\\",\\"perception\\":\\"$perception\\"}\\n"\n    out.print(json)\n    out.flush()',
        content, flags=re.MULTILINE
    )

    # Patch sendActionResult
    content = re.sub(
        r'val payload = JSONObject\(\)\.apply \{[^}]+\}\s*out\.println\(payload\.toString\(\)\)',
        r'val json = "{\\"type\\":\\"action_result\\",\\"id\\":\\"$id\\",\\"success\\":$success}\\n"\n        out.print(json)\n        out.flush()',
        content, flags=re.MULTILINE
    )
    # Scala version
    content = re.sub(
        r'val payload = new JSONObject\(\)\s*payload\.put\("type", "action_result"\)\s*payload\.put\("id", id\)\s*payload\.put\("success", success\)\s*out\.println\(payload\.toString\(\)\)',
        r'val json = s"{\\"type\\":\\"action_result\\",\\"id\\":\\"$id\\",\\"success\\":$success}\\n"\n    out.print(json)\n    out.flush()',
        content, flags=re.MULTILINE
    )

    # Patch handleIncomingLine
    kt_handle = """
    private fun handleIncomingLine(line: String) {
        if (line.isEmpty()) return
        try {
            if (line.contains("\\"type\\":\\"action\\"")) {
                val actionIdPattern = "\\"id\\":\\"(.*?)\\"".toRegex()
                val actionPattern = "\\"action\\":\\"(.*?)\\"".toRegex()
                val actionId = actionIdPattern.find(line)?.groupValues?.get(1) ?: ""
                val rawAction = actionPattern.find(line)?.groupValues?.get(1) ?: ""
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
"""
    scala_handle = """
  private def handleIncomingLine(line: String): Unit = {
    if (line.trim.isEmpty) return
    try {
      if (line.contains("\\"type\\":\\"action\\"")) {
        val actionIdPattern = "\\"id\\":\\"(.*?)\\"".r
        val actionPattern = "\\"action\\":\\"(.*?)\\"".r
        val actionId = actionIdPattern.findFirstMatchIn(line).map(_.group(1)).getOrElse("")
        val rawAction = actionPattern.findFirstMatchIn(line).map(_.group(1)).getOrElse("")
        val (name, args) = parseAction(rawAction)
        actionHandlers.get(name) match {
          case Some(handler) =>
            handler(args, (success: Boolean) => sendActionResult(actionId, success))
          case None =>
            sendActionResult(actionId, true)
        }
      }
    } catch {
      case _: Exception => // ignore parse errors
    }
  }
"""
    if 'BdiClient.kt' in filepath:
        content = re.sub(r'private fun handleIncomingLine.*?(?=\n    private fun parseAction)', kt_handle.strip() + "\n\n", content, flags=re.DOTALL)
    elif 'BdiClient.scala' in filepath:
        content = re.sub(r'private def handleIncomingLine.*?(?=\n  private def parseAction)', scala_handle.strip() + "\n\n", content, flags=re.DOTALL)

    with open(filepath, 'w') as f:
        f.write(content)

patch_file('sdk/kotlin/src/main/kotlin/io/panteao/BdiClient.kt')
patch_file('sdk/scala/src/main/scala/io/panteao/BdiClient.scala')

