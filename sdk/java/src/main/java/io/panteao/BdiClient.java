package io.panteao;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class BdiClient implements AutoCloseable {

    @FunctionalInterface
    public interface ActionHandler {
        void handle(String[] args, Consumer<Boolean> respond);
    }

    private final Socket socket;
    private final PrintWriter out;
    private final BufferedReader in;
    private final Map<String, ActionHandler> actionHandlers = new HashMap<>();
    private final Thread listenerThread;
    private volatile boolean running = true;
    private Process engineProcess;

    private static int getFreePort() throws java.io.IOException {
        try (java.net.ServerSocket s = new java.net.ServerSocket(0)) {
            return s.getLocalPort();
        }
    }

    private static String findBinary() {
        boolean isWin = System.getProperty("os.name").toLowerCase().contains("win");
        String binName = isWin ? "panteao-engine.exe" : "panteao-engine";
        String userDir = System.getProperty("user.dir");
        if (userDir != null) {
            java.io.File cand1 = new java.io.File(userDir, binName);
            if (cand1.exists()) return cand1.getAbsolutePath();
            java.io.File cand2 = new java.io.File(userDir, "bin/" + binName);
            if (cand2.exists()) return cand2.getAbsolutePath();
        }
        return binName;
    }

    public BdiClient(String host, int port) throws Exception {
        this(host, port, null);
    }

    public BdiClient(String host, int port, String project) throws Exception {
        String actualHost = (host == null || host.isEmpty()) ? "127.0.0.1" : host;
        if (project != null && !project.isEmpty()) {
            if (port == 0) {
                port = getFreePort();
            }
            String bin = findBinary();
            ProcessBuilder pb = new ProcessBuilder(bin, project, "--port", String.valueOf(port));
            pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
            pb.redirectError(ProcessBuilder.Redirect.DISCARD);
            this.engineProcess = pb.start();
            Thread.sleep(800);
        } else {
            this.engineProcess = null;
            if (port == 0) port = 44444;
        }

        this.socket = new Socket(actualHost, port);
        this.out = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8), true);
        this.in = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8));

        while (true) {
            String line = in.readLine();
            if (line == null) throw new java.io.IOException("Connection lost during handshake");
            if (line.contains("\"type\":\"mas_ready\"")) {
                break;
            }
        }

        this.listenerThread = new Thread(this::listen);
        this.listenerThread.setDaemon(true);
        this.listenerThread.start();
    }

    private void listen() {
        try {
            String line;
            while (running && (line = in.readLine()) != null) {
                handleIncomingLine(line.trim());
            }
        } catch (Exception e) {
        }
    }

    private static final Pattern TYPE_PATTERN = Pattern.compile("\"type\"\\s*:\\s*\"([^\"]*)\"");
    private static final Pattern ACTION_PATTERN = Pattern.compile("\"action\"\\s*:\\s*\"([^\"]*)\"");
    private static final Pattern ID_PATTERN = Pattern.compile("\"id\"\\s*:\\s*\"([^\"]*)\"");

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

    private static class ParsedAction {
        String name;
        String[] args;
        ParsedAction(String name, String[] args) {
            this.name = name;
            this.args = args;
        }
    }

    private ParsedAction parseAction(String actionStr) {
        int parenIdx = actionStr.indexOf('(');
        if (parenIdx == -1) {
            return new ParsedAction(actionStr.trim(), new String[0]);
        }

        String name = actionStr.substring(0, parenIdx).trim();
        String argsStr = actionStr.substring(parenIdx + 1, actionStr.lastIndexOf(')'));

        List<String> argsList = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean insideQuotes = false;
        int depthBrackets = 0;
        int depthParens = 0;

        for (int i = 0; i < argsStr.length(); i++) {
            char c = argsStr.charAt(i);
            if (c == '"') {
                insideQuotes = !insideQuotes;
                current.append(c);
            } else if (!insideQuotes && c == '[') {
                depthBrackets++;
                current.append(c);
            } else if (!insideQuotes && c == ']') {
                depthBrackets--;
                current.append(c);
            } else if (!insideQuotes && c == '(') {
                depthParens++;
                current.append(c);
            } else if (!insideQuotes && c == ')') {
                depthParens--;
                current.append(c);
            } else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
                argsList.add(cleanArg(current.toString()));
                current.setLength(0);
            } else {
                current.append(c);
            }
        }
        if (current.length() > 0) {
            argsList.add(cleanArg(current.toString()));
        }

        return new ParsedAction(name, argsList.toArray(new String[0]));
    }

    private String cleanArg(String arg) {
        String s = arg.trim();
        if (s.startsWith("\"") && s.endsWith("\"") && s.length() >= 2) {
            return s.substring(1, s.length() - 1);
        }
        return s;
    }

    public void sendMsg(String performative, String sender, String receiver, String content) {
        String escapedContent = content.replace("\"", "\\\"");
        String json = "{\"type\":\"message\",\"performative\":\"" + performative + "\",\"sender\":\"" + sender + "\",\"receiver\":\"" + receiver + "\",\"content\":\"" + escapedContent + "\"}\n";
        out.print(json);
        out.flush();
    }

    public void sendPerception(String action, String perception) {
        String escapedPerception = perception.replace("\"", "\\\"");
        String json = "{\"type\":\"perception\",\"action\":\"" + action + "\",\"perception\":\"" + escapedPerception + "\"}";
        out.println(json);
    }

    public void registerAction(String actionName, ActionHandler handler) {
        actionHandlers.put(actionName, handler);
    }

    private void sendActionResult(String id, boolean success) {
        String json = "{\"type\":\"action_result\",\"id\":\"" + id + "\",\"success\":" + success + "}";
        out.println(json);
    }

    @Override
    public void close() throws Exception {
        running = false;
        if (socket != null) { try { socket.close(); } catch (Exception e) {} }
        if (in != null) { try { in.close(); } catch (Exception e) {} }
        if (out != null) { try { out.close(); } catch (Exception e) {} }
        if (engineProcess != null) {
            try { engineProcess.destroy(); } catch (Exception e) {}
        }
    }
}
