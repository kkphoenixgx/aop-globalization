package br.com.kkphoenix.jason.ipc;

import java.util.logging.Formatter;
import java.util.logging.LogRecord;

public class PanteaoFormatter extends Formatter {
    private static final String RESET = "\u001B[0m";
    private final String[] COLORS = {
        "\u001B[32m", // GREEN
        "\u001B[33m", // YELLOW
        "\u001B[34m", // BLUE
        "\u001B[35m", // PURPLE
        "\u001B[36m"  // CYAN
    };
    
    @Override
    public String format(LogRecord record) {
        String name = record.getLoggerName();
        if (name != null) {
            int lastDot = name.lastIndexOf('.');
            if (lastDot >= 0) {
                name = name.substring(lastDot + 1);
            }
        } else {
            name = "System";
        }
        
        String color = "\u001B[37m"; // WHITE
        if (name.equalsIgnoreCase("MAS") || name.equalsIgnoreCase("IPCEnvironment") || name.equalsIgnoreCase("Logos")) {
            color = "\u001B[1;36m"; // BOLD CYAN
        } else if (name.equalsIgnoreCase("Athena")) {
            color = "\u001B[1;35m"; // BOLD PURPLE
        } else if (name.equalsIgnoreCase("talaria_outgate")) {
            color = "\u001B[1;34m"; // BOLD BLUE
        } else if (name.equalsIgnoreCase("SDK")) {
            color = "\u001B[1;32m"; // BOLD GREEN
        } else {
            int colorIdx = Math.abs(name.hashCode()) % COLORS.length;
            color = COLORS[colorIdx];
        }
        
        String msg = formatMessage(record);
        return String.format("%s[%s]%s %s%n", color, name, RESET, msg);
    }
}
