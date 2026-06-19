package br.com.kkphoenix.jason.ipc;

import java.util.logging.Logger;

public class BrowserBridge {
    private static final Logger logger = Logger.getLogger(BrowserBridge.class.getName());

    static {
        System.loadLibrary("browserBridge");
    }

    //? Native method implemented in JavaScript — called by BrowserAgArch
    //? CheerpJ will map this to Java_br_com_kkphoenix_jason_ipc_BrowserBridge_nativeDispatchAction
    public static native void nativeDispatchAction(String agent, String actionId, String actionTerm);

    public static void dispatchAction(String agent, String actionId, String actionTerm) {
        try {
            nativeDispatchAction(agent, actionId, actionTerm);
        } catch (Throwable t) {
            logger.warning("Failed to dispatch action to JS: " + t.getMessage());
        }
    }

    public static void completeAction(String actionId, boolean success) {
        BrowserAgArch.handleActionResult(actionId, success);
    }
    

    public static void addPercept(String value) {
        BrowserEnvironment env = BrowserEnvironment.getInstance();
        if (env != null) {
            env.addPerception(value);
        } else {
            logger.warning("BrowserEnvironment instance not ready yet.");
        }
    }

    public static void removePercept(String value) {
        BrowserEnvironment env = BrowserEnvironment.getInstance();
        if (env != null) {
            env.removePerception(value);
        } else {
            logger.warning("BrowserEnvironment instance not ready yet.");
        }
    }
}
