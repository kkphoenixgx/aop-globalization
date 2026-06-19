import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;

/**
 * O Desbloqueio de Fundos de Emergência
 *
 * Simulates a legacy banking system that declares an emergency zone
 * and handles the engine's request to liberate emergency funds.
 *
 * Protocol (JSON over TCP, newline-delimited):
 *   -> {"type":"perception","action":"add","perception":"emergency_declared(zona_norte)"}
 *   <- {"type":"action","id":"...","agent":"...","action":"liberate_emergency_funds(zona_norte,1000000)"}
 *   -> {"type":"action_result","id":"<id>","success":true}
 */
public class Client {

    private static final String HOST = "127.0.0.1";
    private static final int PORT = 44444;
    private static final String PERCEPTION = "emergency_declared(zona_norte)";
    private static final String EXPECTED_ACTION = "liberate_emergency_funds";
    private static final long TIMEOUT_MS = 5000;

    public static void main(String[] args) {
        long t0 = System.nanoTime();

        System.out.println("[DILUVIO] O Desbloqueio de Fundos de Emergência — Java");
        System.out.println("[DILUVIO] Connecting to " + HOST + ":" + PORT);

        try (Socket socket = new Socket(HOST, PORT)) {
            socket.setSoTimeout((int) TIMEOUT_MS);

            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream(), "UTF-8"));
            PrintWriter out = new PrintWriter(socket.getOutputStream(), true);

            long tConnect = System.nanoTime();
            System.out.println("[DILUVIO] Connected in " + ms(t0, tConnect) + " ms");

            // Wait for the engine to be ready
            Thread.sleep(1000);

            // Send perception
            String perception = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"" + PERCEPTION + "\"}";
            out.println(perception);
            out.flush();

            long tPerception = System.nanoTime();
            System.out.println("[DILUVIO] Sent perception: " + PERCEPTION);
            System.out.println("[DILUVIO] Perception sent in " + ms(tConnect, tPerception) + " ms");

            // Read lines looking for the action request
            String line;
            long tActionReceived = 0;
            while ((line = in.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;

                System.out.println("[DILUVIO] Received: " + line);

                if (line.contains("\"type\"") && line.contains("\"action\"") && line.contains(EXPECTED_ACTION)) {
                    tActionReceived = System.nanoTime();

                    // Extract the id field
                    String id = extractField(line, "id");
                    if (id == null) {
                        System.err.println("[DILUVIO] ERROR: Could not extract action id");
                        System.exit(1);
                    }

                    System.out.println("[DILUVIO] Action received: " + EXPECTED_ACTION);
                    System.out.println("[DILUVIO] Action id: " + id);
                    System.out.println("[DILUVIO] Engine response time: " + ms(tPerception, tActionReceived) + " ms");

                    // Respond with success
                    String result = "{\"type\":\"action_result\",\"id\":\"" + id + "\",\"success\":true}";
                    out.println(result);
                    out.flush();

                    long tResult = System.nanoTime();
                    System.out.println("[DILUVIO] Sent action_result for id: " + id);
                    System.out.println();
                    System.out.println("=== Timing Metrics ===");
                    System.out.println("  Connection:      " + ms(t0, tConnect) + " ms");
                    System.out.println("  Perception send: " + ms(tConnect, tPerception) + " ms");
                    System.out.println("  Engine response: " + ms(tPerception, tActionReceived) + " ms");
                    System.out.println("  Result send:     " + ms(tActionReceived, tResult) + " ms");
                    System.out.println("  Total:           " + ms(t0, tResult) + " ms");
                    System.out.println("======================");
                    System.out.println();
                    System.out.println("[DILUVIO] SUCCESS");
                    System.exit(0);
                }
            }

            // If we get here, we never received the expected action
            System.err.println("[DILUVIO] ERROR: Connection closed without receiving " + EXPECTED_ACTION);
            System.exit(1);

        } catch (java.net.SocketTimeoutException e) {
            long tTimeout = System.nanoTime();
            System.err.println("[DILUVIO] ERROR: Timeout after " + ms(t0, tTimeout) + " ms waiting for action");
            System.exit(1);
        } catch (Exception e) {
            long tError = System.nanoTime();
            System.err.println("[DILUVIO] ERROR after " + ms(t0, tError) + " ms: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    /**
     * Extract a JSON string field value using simple string parsing.
     * Avoids external JSON library dependencies.
     */
    private static String extractField(String json, String field) {
        String key = "\"" + field + "\"";
        int keyIdx = json.indexOf(key);
        if (keyIdx < 0) return null;

        // Find the colon after the key
        int colonIdx = json.indexOf(':', keyIdx + key.length());
        if (colonIdx < 0) return null;

        // Find the opening quote of the value
        int startQuote = json.indexOf('"', colonIdx + 1);
        if (startQuote < 0) return null;

        // Find the closing quote of the value
        int endQuote = json.indexOf('"', startQuote + 1);
        if (endQuote < 0) return null;

        return json.substring(startQuote + 1, endQuote);
    }

    /**
     * Calculate elapsed time in milliseconds between two nanoTime values.
     */
    private static String ms(long startNano, long endNano) {
        double millis = (endNano - startNano) / 1_000_000.0;
        return String.format("%.2f", millis);
    }
}
