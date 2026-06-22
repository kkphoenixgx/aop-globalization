import re

with open("sdk/java/src/main/java/io/panteao/BdiClient.java", "r") as f:
    content = f.read()

content = content.replace("import org.json.JSONObject;", "import java.util.regex.Matcher;\nimport java.util.regex.Pattern;")

java_handle = """
    private static final Pattern TYPE_PATTERN = Pattern.compile("\"type\"\\\\s*:\\\\s*\"([^\"]*)\"");
    private static final Pattern ACTION_PATTERN = Pattern.compile("\"action\"\\\\s*:\\\\s*\"([^\"]*)\"");
    private static final Pattern ID_PATTERN = Pattern.compile("\"id\"\\\\s*:\\\\s*\"([^\"]*)\"");

    private void handleIncomingLine(String line) {
        if (line.isEmpty()) return;
        try {
            Matcher typeMatcher = TYPE_PATTERN.matcher(line);
            if (typeMatcher.find() && "action".equals(typeMatcher.group(1))) {
                Matcher actionMatcher = ACTION_PATTERN.matcher(line);
                String rawAction = actionMatcher.find() ? actionMatcher.group(1) : "";
                ParsedAction action = parseAction(rawAction);
                ActionHandler handler = actionHandlers.get(action.name);
                
                Matcher idMatcher = ID_PATTERN.matcher(line);
                String actionId = idMatcher.find() ? idMatcher.group(1) : "";

                if (handler != null) {
                    handler.handle(action.args, (success) -> sendActionResult(actionId, success));
                } else {
                    sendActionResult(actionId, true);
                }
            }
        } catch (Exception e) {
        }
    }
"""

content = re.sub(r'    private void handleIncomingLine\(String line\) \{.*?    \}', java_handle.strip('\n'), content, flags=re.DOTALL)

content = content.replace("argsStr.length;", "argsStr.length();")

with open("sdk/java/src/main/java/io/panteao/BdiClient.java", "w") as f:
    f.write(content)

print("Java Fixed")
