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
 * PERFORMANCE AND ARCHITECTURE NOTES:
 * 1. Why AgArch instead of Jason plans (+message)? 
 *    By intercepting messages directly in checkMail(), we steal the messages 
 *    from the mailbox before they enter the agent's Belief Base. This bypasses 
 *    the entire Jason Reasoning Cycle (parsing, unification, plan selection, 
 *    intention generation), making message relaying infinitely faster and cheaper.
 *
 * 2. Why does it not busy-wait? 
 *    The Jason infrastructure automatically puts agent threads to sleep (0% CPU)
 *    when their mailbox, event queue, and intention queue are empty. As soon as 
 *    another agent calls .send(talaria, ...), the infrastructure wakes Talaria up, 
 *    checkMail() runs instantly, relays the message, and the agent goes back to sleep.
 */
public class TalariaAgArch extends AgArch {

    private static final Logger logger = Logger.getLogger("Talaria");

    @Override
    public void init() throws Exception {
        super.init();
        logger.info("Gateway agent initialized.");
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

    private void checkMessage() {
        try {
            if (getTS() == null || getTS().getC() == null) {
                return;
            }
            java.util.Queue<Message> mbox = getTS().getC().getMailBox();
            if (mbox == null || mbox.isEmpty()) {
                return;
            }

            List<Message> toForward = new ArrayList<>(mbox);
            mbox.clear();

            IPCEnvironment env = IPCEnvironment.getInstance();
            if (env == null) return;

            for (Message msg : toForward) {
                JSONObject json = new JSONObject();
                json.put("type", "message");
                json.put("performative", msg.getIlForce());
                json.put("sender", msg.getSender());
                json.put("content", msg.getPropCont() != null ? msg.getPropCont().toString() : "");
                env.sendToClient(json);
            }
        } catch (Exception e) {
            logger.severe("Exception intercepting messages: " + e.getMessage());
        }
    }
}
