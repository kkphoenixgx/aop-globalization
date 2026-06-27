package br.com.kkphoenix.jason.ipc;

import jason.infra.local.RunLocalMAS;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Launcher {
    private static final Logger logger = Logger.getLogger("MAS");
    private static File tempMas2jFile = null;

    static {
        System.setProperty("java.awt.headless", "true");
        System.setProperty("java.util.logging.SimpleFormatter.format", "[%3$s] %5$s%6$s%n");

        try (java.io.InputStream in = Launcher.class.getResourceAsStream("/logging.properties")) {
            if (in != null) {
                java.util.logging.LogManager.getLogManager().readConfiguration(in);
            }
        } 
        catch (Exception e) { }
    }


    public static class AgentConfig {
        String name;
        String aslPath;
        List<String> archs = new ArrayList<>();
        int instances = 1;
    }

    public static void main(String[] args) {

        String projectPath = null;
        List<String> extraArgs = new ArrayList<>();

        //? --------- Simple CLI Parsing for jcm && mas2j files ---------
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            
            if (arg.endsWith(".jcm") || arg.endsWith(".mas2j")) {
                projectPath = arg;
            } else {
                extraArgs.add(arg);
            }
        }
        if (projectPath == null) {
            logger.severe("Error: You must specify a .jcm or .mas2j project file.");
            printUsage();
            System.exit(1);
        }

        //? --------- Handling jcm & mas2j files ---------
        
        File projectFile = new File(projectPath).getAbsoluteFile();
        if (!projectFile.exists()) {
            logger.severe("Project file not found: " + projectFile.getAbsolutePath());
            System.exit(1);
        }

        String projectName = projectFile.getName().toLowerCase();
        if (
            projectName.equals("test.jcm") || projectName.equals("teste.jcm") ||
            projectName.equals("test.mas2j") || projectName.equals("teste.mas2j")
        ) {
            logger.severe("Error: The project name cannot be 'test' or 'teste' due to internal Jason restrictions.");
            System.exit(1);
        }

        String portStr = null;
        for (int i = 0; i < args.length; i++) {
            if (args[i].equals("--port") && i + 1 < args.length) {
                portStr = args[i+1];
            }
        }

        //? Translate JCM to MAS2J if JCM is provided
        if (projectFile.getName().endsWith(".jcm")) {
            try {
                projectPath = translateJcmToMas2j(projectFile, portStr);
            } catch (IOException e) {
                logger.severe("Failed to parse JCM file: " + e.getMessage());
                System.exit(1);
            }
        }


        //? --------- Creating logs --------- 

        File tempLogProps = null;
        try {
            tempLogProps = File.createTempFile("panteao_log_", ".properties");
            tempLogProps.deleteOnExit();
            try (FileWriter writer = new FileWriter(tempLogProps)) {
                writer.write("handlers = java.util.logging.ConsoleHandler\n");
                writer.write(".level = INFO\n");
                writer.write("java.util.logging.ConsoleHandler.level = INFO\n");
                writer.write("java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter\n");
            }
        } catch (IOException e) {
            logger.warning("Failed to create temporary logging configuration: " + e.getMessage());
        }

        //? Build runner arguments: project path MUST be first (args[0]), followed by flags
        List<String> runnerArgs = new ArrayList<>();
        runnerArgs.add(projectPath);
        
        //? Enable headless mode, disable MBeans, RMI and web inspector
        runnerArgs.add("--no-net");
        if (tempLogProps != null) {
            runnerArgs.add("--log-conf");
            runnerArgs.add(tempLogProps.getAbsolutePath());
        }
        runnerArgs.addAll(extraArgs);

        //? --------- CleanUp ---------

        final File finalTempLogProps = tempLogProps;
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (tempMas2jFile != null && tempMas2jFile.exists()) {
                tempMas2jFile.delete();
            }
            if (finalTempLogProps != null && finalTempLogProps.exists()) {
                finalTempLogProps.delete();
            }
        }));

        //? --------- Bootstrap ---------

        try {
            logger.fine("Bootstrapping Jason MAS with project: " + projectPath);
            String[] runArgs = runnerArgs.toArray(new String[0]);
            RunLocalMAS.main(runArgs);
        } catch (Throwable e) {
            logger.severe("Failed to run Jason MAS: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    //? ----------- Helpers -----------

    private static String translateJcmToMas2j(File jcmFile, String portStr) throws IOException {
        logger.fine("Parsing JCM file: " + jcmFile.getAbsolutePath());
        String content = Files.readString(jcmFile.toPath(), StandardCharsets.UTF_8);

        // Strip single line comments: // ...
        content = content.replaceAll("//.*", "");

        // Strip block comments: /* ... */
        content = content.replaceAll("/\\*([\\s\\S]*?)\\*/", "");

        List<AgentConfig> configs = new ArrayList<>();

        // Match: agent <name> [ : <asl> ]
        Pattern agentPattern = Pattern.compile("agent\\s+([a-zA-Z0-9_\\-]+)(?:\\s*:\\s*([a-zA-Z0-9_\\-\\.\\/\\\"\\']+))?");
        Matcher matcher = agentPattern.matcher(content);

        while (matcher.find()) {
            AgentConfig config = new AgentConfig();
            config.name = matcher.group(1);
            if (config.name.equalsIgnoreCase("test") || config.name.equalsIgnoreCase("teste")) {
                throw new IOException("Error: Agent name cannot be 'test' or 'teste' due to internal Jason restrictions.");
            }
            if (matcher.group(2) != null) {
                config.aslPath = matcher.group(2).replace("\"", "").replace("'", "");
            } else {
                config.aslPath = config.name + ".asl";
            }

            int end = matcher.end();

            // Look for instances in options block [instances=N]
            Pattern bracketPattern = Pattern.compile("\\[[^\\]]*instances\\s*=\\s*(\\d+)[^\\]]*\\]");
            Matcher bracketMatcher = bracketPattern.matcher(content.substring(end, Math.min(content.length(), end + 100)));
            if (bracketMatcher.find()) {
                config.instances = Integer.parseInt(bracketMatcher.group(1));
            }

            // Look for properties block '{'
            int openBrace = content.indexOf('{', end);
            int nextAgent = content.indexOf("agent", end);

            if (openBrace != -1 && (nextAgent == -1 || openBrace < nextAgent)) {
                int closeBrace = findClosingBrace(content, openBrace);
                if (closeBrace != -1) {
                    String properties = content.substring(openBrace + 1, closeBrace);
                    parseAgentProperties(properties, config);
                }
            }
            configs.add(config);
        }

        if (configs.isEmpty()) {
            throw new IOException("No agents defined in JCM project file.");
        }

        boolean hasPort = (portStr != null);
        // Generate MAS2J
        StringBuilder sb = new StringBuilder();
        sb.append("MAS temp_mas {\n");
        sb.append("    infrastructure: Centralised\n\n");
        if (hasPort) {
            sb.append("    environment: br.com.kkphoenix.jason.ipc.IPCEnvironment(\"--port\", \"" + portStr + "\")\n\n");
        }

        // Collect source paths relative to the current working directory (Cwd)
        java.nio.file.Path userCwd = new File(".").getAbsoluteFile().toPath().normalize();
        List<String> sourcePaths = new ArrayList<>();
        for (AgentConfig config : configs) {
            // Register original user architectures in the static registry
            List<String> userArchs = new java.util.ArrayList<>(config.archs);
            ArchitectureRegistry.register(config.name, userArchs);

            // User agents have no special arch — they communicate via .send(talaria, ...)
            // config.archs stays as defined by the user (from the .jcm file)
            String escapedAslPath = config.aslPath.replace("\\", "/");
            File aslFile = new File(escapedAslPath);
            if (!aslFile.isAbsolute()) {
                aslFile = new File(jcmFile.getParentFile(), escapedAslPath);
            }
            java.nio.file.Path aslParent = aslFile.getParentFile().toPath().toAbsolutePath().normalize();
            java.nio.file.Path relativePath = userCwd.relativize(aslParent);
            String relPathStr = relativePath.toString().replace("\\", "/");
            if (relPathStr.isEmpty()) {
                relPathStr = ".";
            }
            if (!sourcePaths.contains(relPathStr)) {
                sourcePaths.add(relPathStr);
            }
        }

        sb.append("    agents:\n");

        // Inject the Talaria gateway agent when running in IPC mode
        if (hasPort) {
            sb.append("        talaria talaria.asl agentArchClass br.com.kkphoenix.jason.ipc.TalariaAgArch;\n");
            try {
                File talariaAslFile = new File(jcmFile.getParentFile(), "talaria.asl");
                if (!talariaAslFile.exists()) {
                    try (java.io.FileWriter aslWriter = new java.io.FileWriter(talariaAslFile)) {
                        aslWriter.write("!start.\n+!start <- .print(\"Talaria agent started.\").\n");
                    }
                }
            } catch (Exception e) {
                logger.warning("Could not dynamically write talaria.asl: " + e.getMessage());
            }
        }

        for (AgentConfig config : configs) {
            File aslFile = new File(config.aslPath);
            String simpleName = aslFile.getName(); // e.g. bob.asl

            sb.append("        ").append(config.name).append(" ").append(simpleName);

            if (!config.archs.isEmpty()) {
                sb.append(" agentArchClass ");
                for (int i = 0; i < config.archs.size(); i++) {
                    sb.append(config.archs.get(i));
                    if (i < config.archs.size() - 1) {
                        sb.append(", ");
                    }
                }
            }
            if (config.instances > 1) {
                sb.append(" #").append(config.instances);
            }
            sb.append(";\n");
        }
        sb.append("\n");

        // Write source paths after agents to satisfy MAS2J parser grammar constraints
        if (!sourcePaths.isEmpty()) {
            sb.append("    aslSourcePath:\n");
            for (String sp : sourcePaths) {
                sb.append("        \"").append(sp).append("\";\n");
            }
            sb.append("\n");
        }
        sb.append("}\n");

        logger.fine("Generated MAS2J Content:\n" + sb.toString());

        // Create the hidden mas2j file in the JCM's parent folder to resolve relative paths
        String baseName = jcmFile.getName();
        int dotIdx = baseName.lastIndexOf('.');
        if (dotIdx != -1) {
            baseName = baseName.substring(0, dotIdx);
        }
        tempMas2jFile = new File(jcmFile.getParentFile(), "." + baseName + ".mas2j");
        tempMas2jFile.deleteOnExit();

        try (FileWriter writer = new FileWriter(tempMas2jFile)) {
            writer.write(sb.toString());
        }

        logger.fine("Generated temporary MAS2J project file at: " + tempMas2jFile.getAbsolutePath());
        return tempMas2jFile.getAbsolutePath();
    }

    private static int findClosingBrace(String content, int openBraceIdx) {
        int count = 1;
        for (int i = openBraceIdx + 1; i < content.length(); i++) {
            char c = content.charAt(i);
            if (c == '{') {
                count++;
            } else if (c == '}') {
                count--;
                if (count == 0) {
                    return i;
                }
            }
        }
        return -1;
    }

    private static void parseAgentProperties(String propsBlock, AgentConfig config) {
        // Look for agarch or ag-arch with optional multiple comma-separated values
        Pattern archPattern = Pattern.compile("(?:ag-arch|agarch)\\s*:\\s*([a-zA-Z0-9_\\-\\.\\,\\s]+)");
        Matcher archMatcher = archPattern.matcher(propsBlock);
        while (archMatcher.find()) {
            String[] archs = archMatcher.group(1).split(",");
            for (String arch : archs) {
                String cleanArch = arch.trim();
                if (!cleanArch.isEmpty() && !config.archs.contains(cleanArch)) {
                    config.archs.add(cleanArch);
                }
            }
        }

        // Look for instances
        Pattern instPattern = Pattern.compile("instances\\s*:\\s*(\\d+)");
        Matcher instMatcher = instPattern.matcher(propsBlock);
        if (instMatcher.find()) {
            config.instances = Integer.parseInt(instMatcher.group(1));
        }
    }

    private static void printUsage() {
        System.out.println("Usage: panteao <project.jcm | project.mas2j> [options]");
    }
}
