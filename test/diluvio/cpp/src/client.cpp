#include <iostream>
#include <chrono>
#include <thread>
#include <atomic>
#include "panteao_client.h"

using namespace panteao;

int main() {
    std::cout << "[DILUVIO] C++ client starting" << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    BdiClient client;
    std::atomic<bool> action_handled{false};
    
    client.registerAction("open_gate", [&](const std::vector<std::string>& args, std::function<void(bool)> respond) {
        std::cout << "[DILUVIO] Action handled: open_gate" << std::endl;
        if (!args.empty()) {
            std::cout << "[DILUVIO] Args: " << args[0] << std::endl;
        }
        respond(true);
        action_handled = true;
    });
    
    if (!client.connect("127.0.0.1", 44444)) {
        std::cout << "[DILUVIO] FAILURE" << std::endl;
        return 1;
    }
    
    std::cout << "[DILUVIO] Connected!" << std::endl;
    client.sendMsg("tell", "external", "orquestrador", "gate_pressure(gate_2,95)");
    
    int elapsed = 0;
    while (!action_handled && elapsed < 50) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        elapsed++;
    }
    
    client.close();
    
    if (action_handled) {
        std::cout << "[DILUVIO] SUCCESS" << std::endl;
        return 0;
    } else {
        std::cout << "[DILUVIO] TIMEOUT" << std::endl;
        return 1;
    }
}
