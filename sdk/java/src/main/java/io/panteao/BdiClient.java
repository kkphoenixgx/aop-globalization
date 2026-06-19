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
import org.json.JSONObject;

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

    public BdiClient(String host, int port) throws Exception {
        this.socket = new Socket(host, port);
        this.out = new PrintWriter(new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.UTF_8), true);
        this.in = new BufferedReader(new InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8));
        
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
            // Socket closed or connection lost
        }
    }

    private void handleIncomingLine(String line) {
        if (line.isEmpty()) return;
        try {
            JSONObject msg = new JSONObject(line);
            if ("action".equals(msg.optString("type"))) {
                String rawAction = msg.optString("action", "");
                ParsedAction action = parseAction(rawAction);
                ActionHandler handler = actionHandlers.get(action.name);
                
                if (handler != null) {
                    String actionId = msg.optString("id");
                    handler.handle(action.args, (success) -> sendActionResult(actionId, success));
                } else {
                    // Auto-succeed if no handler
                    sendActionResult(msg.optString("id"), true);
                }
            }
        } catch (Exception e) {
            // JSON parse error
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

        for (int i = 0; i < argsStr.length(); i++) {
            char c = argsStr.charAt(i);
            if (c == '"') {
                insideQuotes = !insideQuotes;
            } else if (c == ',' && !insideQuotes) {
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
        return arg.trim().replaceAll("^\"|\"$", "");
    }

    public void sendPerception(String action, String perception) {
        JSONObject payload = new JSONObject();
        payload.put("type", "perception");
        payload.put("action", action);
        payload.put("perception", perception);
        out.println(payload.toString());
    }

    public void registerAction(String actionName, ActionHandler handler) {
        actionHandlers.put(actionName, handler);
    }

    private void sendActionResult(String id, boolean success) {
        JSONObject payload = new JSONObject();
        payload.put("type", "action_result");
        payload.put("id", id);
        payload.put("success", success);
        out.println(payload.toString());
    }

    @Override
    public void close() throws Exception {
        running = false;
        in.close();
        out.close();
        socket.close();
    }
}
