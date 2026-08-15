package br.com.kkphoenix.jason.ipc;

import jason.architecture.AgArch;
import jason.asSemantics.Message;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;
import org.json.JSONObject;

/**
 * TalariaAgArch — Architecture for the "talaria_outgate" gateway agent.
 * 
 * Intercepts all messages arriving in talaria_outgate's mailbox (sent by user agents
 * that want to talk to the external C++/TypeScript application) and routes them 
 * directly to the TCP client through IPCEnvironment.
 * 
 * User agents (like player, enemy, system_manager) communicate with
 * the external world exclusively by sending Jason messages to "talaria_outgate":
 * 
 *   .send(talaria_outgate, tell, update_dashboard("EVACUATE", "critical"))
 *   .send(talaria_outgate, achieve, play_sound("explosion.wav"))
 * 
 * Flow:
 * 1. User Agent -> .send(talaria_outgate, ...)
 * 2. Jason Engine routes message to talaria_outgate's mailbox.
 * 3. TalariaAgArch intercepts `receiveMsg` or overrides reasoning cycle.
 * 4. TalariaAgArch forwards the Message to IPCEnvironment.
 * 5. IPCEnvironment serializes to JSON and sends over TCP.
 * 
 * Note: Talaria is purely reactive and stateless. It has no goals or plans.
 * To prevent the Jason engine from suspending/killing it for being idle,
 * we ensure it stays active or simply intercepts messages transparently.
 * In Jason, if an agent has no plans and no messages, it sleeps. When
 * another agent calls .send(talaria_outgate, ...), the infrastructure wakes Talaria up, 
 * delivering the message to this Arch.
 */
public class TalariaAgArch extends AgArch {

    private static final Logger logger = Logger.getLogger("Talaria");

    @Override
    public void init() throws Exception {
        super.init();
        logger.info("Talaria gateway agent to send your messages, milord");
    }

    /**
     * Called every reasoning cycle.
     * Intercepts ALL messages in talaria_outgate's mailbox and forwards them to the TCP client.
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
