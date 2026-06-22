import io.panteao.BdiClient;
import java.util.List;

public class Client {
    public static void main(String[] args) throws Exception {
        System.out.println("[DILUVIO] Java client starting");
        BdiClient client = new BdiClient("127.0.0.1", 44444);

        Thread timeout = new Thread(() -> {
            try { Thread.sleep(5000); } catch (Exception e) {}
            System.out.println("[DILUVIO] TIMEOUT");
            try { client.close(); } catch(Exception e) {}
            System.exit(1);
        });
        timeout.start();

        client.registerAction("liberate_emergency_funds", (String[] actionArgs, java.util.function.Consumer<Boolean> respond) -> {
            System.out.println("[DILUVIO] Action handled: liberate_emergency_funds");
            respond.accept(true);
            System.out.println("[DILUVIO] SUCCESS");
            try { client.close(); } catch(Exception e) {}
            System.exit(0);
        });

        try {
            System.out.println("[DILUVIO] Connected!");
            client.sendMsg("tell", "external", "orquestrador", "emergency_declared(zone1)");
            Thread.sleep(Long.MAX_VALUE);
        } catch (Exception e) {
            System.out.println("[DILUVIO] FAILURE: " + e.getMessage());
            System.exit(1);
        }
    }
}
