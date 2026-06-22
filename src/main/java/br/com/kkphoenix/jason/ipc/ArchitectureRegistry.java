package br.com.kkphoenix.jason.ipc;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

public class ArchitectureRegistry {
    private static final ConcurrentHashMap<String, List<String>> registry = new ConcurrentHashMap<>();

    public static void register(String agentName, List<String> archs) {
        registry.put(agentName, archs);
    }

    public static List<String> get(String agentName) {
        return registry.get(agentName);
    }
}
