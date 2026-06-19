package br.com.kkphoenix.jason.ipc;

import jason.asSyntax.Literal;
import jason.asSyntax.ASSyntax;
import jason.environment.Environment;
import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.logging.Logger;
import org.json.JSONObject;

public class IPCEnvironment extends Environment {
    private static final Logger logger = Logger.getLogger(IPCEnvironment.class.getName());
    private static IPCEnvironment instance;
    private ServerSocket serverSocket;
    private Socket clientSocket;
    private BufferedReader in;
    private PrintWriter out;
    private Thread listenerThread;
    private volatile boolean running = true;

    public static IPCEnvironment getInstance() {
        return instance;
    }

    @Override
    public void init(String[] args) {
        instance = this;
        super.init(args);
        
        int port = -1;
        for (int i = 0; i < args.length; i++) {
            if (args[i].equals("--port") && i + 1 < args.length) {
                port = Integer.parseInt(args[i+1]);
                break;
            }
        }
        
        if (port != -1) {
            startServer(port);
        } else {
            logger.info("No port specified. IPC Environment started in standalone mode.");
        }
    }

    private void startServer(int port) {
        try {
            serverSocket = new ServerSocket(port);
            logger.info("IPC Environment Server started on port " + port + ". Waiting for client...");
            
            clientSocket = serverSocket.accept();
            logger.info("Client connected to IPC Environment.");
            
            in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            out = new PrintWriter(clientSocket.getOutputStream(), true);
            
            listenerThread = new Thread(this::listenToClient);
            listenerThread.setDaemon(true);
            listenerThread.start();
            
        } catch (IOException e) {
            logger.severe("Failed to start IPC Server: " + e.getMessage());
        }
    }

    private void listenToClient() {
        try {
            String line;
            while (running && (line = in.readLine()) != null) {
                handleMessage(line);
            }
        } catch (IOException e) {
            if (running) {
                logger.warning("Connection to client lost: " + e.getMessage());
            }
        }
    }

    private synchronized void handleMessage(String line) {
        try {
            logger.info("IPC Raw Line Received: " + line);
            JSONObject json = new JSONObject(line);
            String type = json.optString("type");
            if ("perception".equals(type)) {
                String action = json.optString("action");
                String value = json.optString("perception");
                Literal p = ASSyntax.parseLiteral(value);
                if ("add".equals(action)) {
                    addPercept(p);
                } else if ("remove".equals(action)) {
                    removePercept(p);
                }
            } else if ("action_result".equals(type)) {
                String actionId = json.optString("id");
                boolean success = json.optBoolean("success", false);
                IPCAgArch.handleActionResult(actionId, success);
            } else if ("message".equals(type)) {
                String sender = json.optString("sender", "external");
                String receiver = json.optString("receiver");
                String performative = json.optString("performative", "tell");
                String content = json.optString("content");
                
                jason.asSemantics.Message msg = new jason.asSemantics.Message(
                    performative,
                    sender,
                    receiver,
                    jason.asSyntax.ASSyntax.parseTerm(content)
                );
                
                jason.infra.local.LocalAgArch arch = jason.infra.centralised.RunCentralisedMAS.getRunner().getAg(receiver);
                if (arch != null) {
                    arch.getTS().getC().addMsg(msg);
                } else {
                    logger.warning("Receiver agent not found for IPC speech act: " + receiver);
                }
            }
        } catch (Exception e) {
            logger.severe("Error handling message: " + e.getMessage() + " | Line: " + line);
        }
    }

    public synchronized void sendToClient(JSONObject json) {
        if (out != null) {
            out.println(json.toString());
        }
    }

    @Override
    public void stop() {
        running = false;
        try {
            if (clientSocket != null) clientSocket.close();
            if (serverSocket != null) serverSocket.close();
        } catch (IOException e) {
            // ignore
        }
        super.stop();
    }
}
