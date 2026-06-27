package br.com.kkphoenix.jason.ipc;

import jason.architecture.AgArch;
import jason.asSemantics.ActionExec;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.logging.Logger;
import java.util.List;
import org.json.JSONObject;

public class IPCAgArch extends AgArch {
    private static final Logger logger = Logger.getLogger(IPCAgArch.class.getName());
    private static final AtomicLong actionIdGen = new AtomicLong(0);

    public static class PendingAction {
        public final IPCAgArch arch;
        public final ActionExec action;

        public PendingAction(IPCAgArch arch, ActionExec action) {
            this.arch = arch;
            this.action = action;
        }
    }

    private static final ConcurrentHashMap<String, PendingAction> pendingActions = new ConcurrentHashMap<>();

    @Override
    public void init() throws Exception {
        super.init();
        List<String> chainedArchs = ArchitectureRegistry.get(getAgName());
        if (chainedArchs != null) {
            for (String archClass : chainedArchs) {
                if (archClass.equals(IPCAgArch.class.getName()) || archClass.equals("br.com.kkphoenix.jason.ipc.IPCAgArch")) {
                    continue;
                }
                try {
                    jason.architecture.AgArch arch = (jason.architecture.AgArch) Class.forName(archClass).getDeclaredConstructor().newInstance();
                    arch.setTS(getTS());
                    insertAgArch(arch);
                } catch (ClassNotFoundException e) {
                    if (System.getProperty("org.graalvm.nativeimage.imagecode") != null) {
                        System.err.println("\n================================================================================");
                        System.err.println(" [PANTEÃO FATAL ERROR] Custom Agent Architecture Not Supported in Native Mode!");
                        System.err.println(" You tried to load: " + archClass);
                        System.err.println(" The compiled GraalVM native engine (panteao-engine) runs in a closed-world");
                        System.err.println(" environment and cannot load arbitrary/custom classes at runtime.");
                        System.err.println(" To use custom architectures or external libraries, you MUST run Panteão");
                        System.err.println(" using JVM mode (JAR) which dynamically supports libraries in the classpath.");
                        System.err.println("================================================================================");
                        System.exit(1);
                    }
                    throw e;
                }
            }
        }
    }

    @Override
    public void act(ActionExec action) {
        String actionId = "act_" + actionIdGen.incrementAndGet();
        pendingActions.put(actionId, new PendingAction(this, action));

        JSONObject msg = new JSONObject();
        msg.put("type", "action");
        msg.put("id", actionId);
        msg.put("agent", getAgName());
        msg.put("action", action.getActionTerm().toString());

        IPCEnvironment env = IPCEnvironment.getInstance();
        if (env != null) {
            env.sendToClient(msg);
        } else {
            logger.severe("IPC Environment not running. Cannot execute action: " + action.getActionTerm());
            pendingActions.remove(actionId);
            action.setResult(false);
            actionExecuted(action);
        }
    }

    @Override
    public void sendMsg(jason.asSemantics.Message m) throws Exception {
        super.sendMsg(m);
        
        JSONObject msg = new JSONObject();
        msg.put("type", "message");
        msg.put("ilf", m.getIlForce());
        msg.put("sender", m.getSender());
        msg.put("receiver", m.getReceiver());
        msg.put("message", m.getPropCont().toString());
        
        // Backward compatibility
        msg.put("performative", m.getIlForce());
        msg.put("content", m.getPropCont().toString());
        
        if (m.getMsgId() != null) {
            msg.put("answer", m.getMsgId());
        }
        
        IPCEnvironment env = IPCEnvironment.getInstance();
        if (env != null) {
            env.sendToClient(msg);
        }
    }

    public static void handleActionResult(String actionId, boolean success) {
        PendingAction pending = pendingActions.remove(actionId);
        if (pending != null) {
            pending.action.setResult(success);
            pending.arch.actionExecuted(pending.action);
        } else {
            logger.warning("No pending action found for ID: " + actionId);
        }
    }
}
