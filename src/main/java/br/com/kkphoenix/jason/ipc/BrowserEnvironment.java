package br.com.kkphoenix.jason.ipc;

import jason.asSyntax.Literal;
import jason.asSyntax.ASSyntax;
import jason.environment.Environment;
import java.util.logging.Logger;

public class BrowserEnvironment extends Environment {
    private static final Logger logger = Logger.getLogger(BrowserEnvironment.class.getName());
    private static BrowserEnvironment instance;

    public static BrowserEnvironment getInstance() {
        return instance;
    }

    @Override
    public void init(String[] args) {
        instance = this;
        super.init(args);
        logger.info("BrowserEnvironment initialized successfully.");
        System.setProperty("panteao.browser", "true");
    }

    public void addPerception(String value) {
        try {
            Literal p = ASSyntax.parseLiteral(value);
            addPercept(p);
            logger.info("Added browser perception: " + value);
        } 
        catch (Exception e) {
            logger.severe("Failed to parse perception term: " + value + " | Error: " + e.getMessage());
        }
    }

    public void removePerception(String value) {
        try {
            Literal p = ASSyntax.parseLiteral(value);
            removePercept(p);
            logger.info("Removed browser perception: " + value);
        } 
        catch (Exception e) {
            logger.severe("Failed to parse perception term: " + value + " | Error: " + e.getMessage());
        }
    }

    @Override
    public void stop() {
        instance = null;
        super.stop();
    }
}
