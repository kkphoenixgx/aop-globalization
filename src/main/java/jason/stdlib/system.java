package jason.stdlib;

import jason.asSemantics.DefaultInternalAction;
import jason.asSemantics.TransitionSystem;
import jason.asSemantics.Unifier;
import jason.asSyntax.Term;
import jason.asSyntax.StringTerm;
import java.util.logging.Logger;

public class system extends DefaultInternalAction {
    private static final Logger logger = Logger.getLogger(system.class.getName());

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        if (Boolean.getBoolean("panteao.browser")) {
            logger.warning("[Panteão Browser Sandbox] Blocked execution of .system internal action to prevent security crashes.");
            return false;
        }

        //? Fallback to standard local execution on non-browser platforms
        if (args.length > 0 && args[0].isString()) {
            String cmd = ((StringTerm) args[0]).getString();
            try {
                Process p = Runtime.getRuntime().exec(cmd);
                return p.waitFor() == 0;
            } catch (Exception e) {
                logger.severe("Failed to execute local system command: " + cmd + " | Error: " + e.getMessage());
                return false;
            }
        }
        return false;
    }
}
