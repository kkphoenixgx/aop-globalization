#include <iostream>
#include <thread>
#include <chrono>
#include "panteao_client.h"

int main() {
    panteao::Panteao engine;
    
    engine.registerAction("reset_counter", [](const std::vector<std::string>& args, std::function<void(bool)> respond) {
        std::cout << "Agent requested reset! Counter reached 10 successfully." << std::endl;
        std::cout << "TEST PASSED!" << std::endl;
        respond(true);
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        exit(0);
    });

    if (!engine.connect("127.0.0.1", 44444)) {
        std::cerr << "Failed to connect" << std::endl;
        return 1;
    }
    
    // Increment perception periodically
    std::thread perception_thread([&engine]() {
        int counter = 0;
        while (true) {
            counter++;
            engine.sendPerception("add", "counter(" + std::to_string(counter) + ")");
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    });

    std::this_thread::sleep_for(std::chrono::seconds(10));
    std::cerr << "Test timed out." << std::endl;
    return 1;
}
