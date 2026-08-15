package br.com.kkphoenix.jason.ipc;

import java.util.logging.LogRecord;
import java.util.logging.StreamHandler;

public class PanteaoHandler extends StreamHandler {
    public PanteaoHandler() {
        super(System.out, new PanteaoFormatter());
        setLevel(java.util.logging.Level.ALL);
    }

    @Override
    public synchronized void publish(LogRecord record) {
        super.publish(record);
        flush();
    }

    @Override
    public synchronized void close() throws SecurityException {
        flush();
        super.close();
    }
}
