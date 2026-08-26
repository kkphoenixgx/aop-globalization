#include <iostream>
#include <thread>
#include <chrono>
#include "panteao_client.h"

int main() {
    panteao::Panteao engine;
    
    engine.registerAction("execute_native_test", [](const std::string& agentName, const std::vector<std::string>& args, std::function<void(bool)> respond) {
        std::cout << "Action execute_native_test intercepted! args[0]: " << (args.empty() ? "" : args[0]) << std::endl;
        std::cout << "TEST PASSED!" << std::endl;
        respond(true);
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        exit(0);
    });

    if (!engine.connect("127.0.0.1", 44444)) {
        std::cerr << "Failed to connect" << std::endl;
        return 1;
    }
    
    std::this_thread::sleep_for(std::chrono::seconds(15));
    std::cerr << "Test timed out." << std::endl;
    return 1;
}
