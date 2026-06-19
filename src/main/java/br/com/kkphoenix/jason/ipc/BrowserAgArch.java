package br.com.kkphoenix.jason.ipc;

import jason.architecture.AgArch;
import jason.asSemantics.ActionExec;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.logging.Logger;

public class BrowserAgArch extends AgArch {
    private static final Logger logger = Logger.getLogger(BrowserAgArch.class.getName());
    private static final AtomicLong actionIdGen = new AtomicLong(0);

    public static class PendingAction {
        public final BrowserAgArch arch;
        public final ActionExec action;

        public PendingAction(BrowserAgArch arch, ActionExec action) {
            this.arch = arch;
            this.action = action;
        }
    }

    private static final ConcurrentHashMap<String, PendingAction> pendingActions = new ConcurrentHashMap<>();

    @Override
    public void act(ActionExec action) {
        String actionId = "browser_act_" + actionIdGen.incrementAndGet();
        pendingActions.put(actionId, new PendingAction(this, action));

        String agent = getAgName();
        String actionTerm = action.getActionTerm().toString();

        BrowserBridge.dispatchAction(agent, actionId, actionTerm);
    }

    public static void handleActionResult(String actionId, boolean success) {
        PendingAction pending = pendingActions.remove(actionId);
        if (pending != null) {
            pending.action.setResult(success);
            pending.arch.actionExecuted(pending.action);
        } else {
            logger.warning("No pending browser action found for ID: " + actionId);
        }
    }
}
