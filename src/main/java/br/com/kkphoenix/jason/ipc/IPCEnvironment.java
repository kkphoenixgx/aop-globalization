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
    private static final Logger logger = Logger.getLogger("MAS");
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
            serverSocket = new ServerSocket();
            serverSocket.setReuseAddress(true);
            serverSocket.bind(new java.net.InetSocketAddress(port));
            logger.info("IPC Environment Server started on port " + port + ". Waiting for client...");
            
            clientSocket = serverSocket.accept();
            logger.info("Client connected to IPC Environment.");
            
            in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            out = new PrintWriter(clientSocket.getOutputStream(), true);
            
            listenerThread = new Thread(this::listenToClient);
            listenerThread.setDaemon(true);
            listenerThread.start();

            Thread readyNotifier = new Thread(() -> {
                try {
                    while (running) {
                        jason.infra.local.BaseLocalMAS runner = jason.infra.centralised.RunCentralisedMAS.getRunner();
                        if (runner != null && runner.getAgs() != null && !runner.getAgs().isEmpty()) {
                            Thread.sleep(100);
                            JSONObject readyMsg = new JSONObject();
                            readyMsg.put("type", "mas_ready");
                            sendToClient(readyMsg);
                            logger.info("Sent mas_ready event to client.");
                            break;
                        }
                        Thread.sleep(50);
                    }
                } catch (Exception e) {
                    logger.warning("Error checking MAS readiness: " + e.getMessage());
                }
            });
            readyNotifier.setDaemon(true);
            readyNotifier.start();
            
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
            logger.fine("IPC Raw Line Received: " + line);
            JSONObject json = new JSONObject(line);
            String type = json.optString("type");

            if ("message".equals(type)) {
                String sender = json.optString("sender", "external");
                String receiver = json.optString("receiver");
                
                // Fallback to 'performative' for backwards compatibility, but prefer 'ilf' as per KQML/Jason specs
                String performative = json.optString("ilf");
                if (performative.isEmpty()) {
                    performative = json.optString("performative", "tell");
                }
                
                String content = json.optString("message");
                if (content.isEmpty()) {
                    content = json.optString("content");
                }
                
                String answer = json.optString("answer");
                String timeoutStr = json.optString("timeout");

                jason.asSemantics.Message msg = new jason.asSemantics.Message(
                    performative,
                    sender,
                    receiver,
                    jason.asSyntax.ASSyntax.parseTerm(content)
                );
                
                // Support optional KQML Jason Message fields
                if (!answer.isEmpty()) {
                    msg.setMsgId(answer);
                }
                
                // Although Jason message class doesn't store timeout natively, we keep parsing it as per KQML.

                jason.infra.local.LocalAgArch arch = jason.infra.centralised.RunCentralisedMAS.getRunner().getAg(receiver);
                if (arch != null) {
                    arch.getTS().getC().addMsg(msg);
                } else {
                    logger.warning("Receiver agent not found: " + receiver);
                }
            } else {
                logger.warning("Unknown message type from client: " + type);
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
