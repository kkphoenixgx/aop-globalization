package br.com.kkphoenix.jason.ipc;

import jason.architecture.AgArch;
import jason.asSemantics.Message;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;
import org.json.JSONObject;

/**
 * TalariaAgArch — Architecture for the "talaria" gateway agent.
 *
 * Intercepts all messages arriving in talaria's mailbox (sent by user agents
 * via native Jason .send) and forwards them to the external TCP client.
 *
 * This implements the Gateway Agent pattern: user agents communicate with
 * the external world exclusively by sending Jason messages to "talaria":
 *
 *   .send(talaria, tell, update_dashboard("EVACUATE", "critical"))
 *
 * The SDK receives:
 *   {"type":"message","performative":"tell","sender":"orquestrador","content":"update_dashboard(...)"}
 *
 * No action interception, no action_result handshake. Pure BDI communication.
 */
public class TalariaAgArch extends AgArch {

    private static final Logger logger = Logger.getLogger(TalariaAgArch.class.getName());

    @Override
    public void init() throws Exception {
        super.init();
        logger.info("[Talaria] Gateway agent initialized.");
    }

    /**
     * Called every reasoning cycle.
     * Intercepts ALL messages in talaria's mailbox and forwards them to the TCP client.
     * Talaria itself never processes them as beliefs/goals — it is a transparent relay.
     */
    @Override
    public void checkMail() {
        super.checkMail();
        checkMessage();
    }

    private int callCount = 0;

    public void checkMessage() {
        try {
            callCount++;
            if (callCount <= 10 || callCount % 100 == 0) {
                logger.info("[Talaria] checkMessage call count: " + callCount);
            }

            if (getTS() == null) {
                logger.warning("[Talaria] getTS() is null!");
                return;
            }
            if (getTS().getC() == null) {
                logger.warning("[Talaria] getTS().getC() is null!");
                return;
            }
            java.util.Queue<Message> mbox = getTS().getC().getMailBox();
            if (mbox == null) {
                logger.warning("[Talaria] Mailbox is null!");
                return;
            }

            if (!mbox.isEmpty()) {
                logger.info("[Talaria] Intercepted " + mbox.size() + " messages in checkMessage.");
                List<Message> toForward = new ArrayList<>(mbox);
                mbox.clear();

                IPCEnvironment env = IPCEnvironment.getInstance();
                for (Message msg : toForward) {
                    if (env == null) {
                        logger.severe("[Talaria] IPCEnvironment not available. Dropping message from: " + msg.getSender());
                        continue;
                    }
                    JSONObject json = new JSONObject();
                    json.put("type", "message");
                    json.put("performative", msg.getIlForce());
                    json.put("sender", msg.getSender());
                    json.put("content", msg.getPropCont() != null ? msg.getPropCont().toString() : "");
                    env.sendToClient(json);
                    logger.info("[Talaria] Relayed message to client: " + json);
                }
            }
        } catch (Exception e) {
            logger.severe("[Talaria] Exception in checkMessage: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
