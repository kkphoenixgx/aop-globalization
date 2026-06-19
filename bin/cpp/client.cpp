#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <cstring>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

// A simple C++ client that connects to the Panteão BDI engine over TCP sockets
int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <port>\n";
        return 1;
    }
    int port = std::stoi(argv[1]);

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << "Failed to create socket\n";
        return 1;
    }

    sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr);

    std::cout << "[C++ Client] Connecting to Panteao BDI engine on port " << port << "...\n";
    if (connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        std::cerr << "Connection failed\n";
        return 1;
    }
    std::cout << "[C++ Client] Connected successfully!\n";

    // Start a thread to read actions from the engine
    std::thread receiver([sock]() {
        char buffer[1024];
        std::string incoming = "";
        while (true) {
            memset(buffer, 0, sizeof(buffer));
            int bytes_read = recv(sock, buffer, sizeof(buffer) - 1, 0);
            if (bytes_read <= 0) {
                std::cout << "[C++ Client] Disconnected from engine.\n";
                break;
            }
            incoming += buffer;
            size_t newline_pos;
            while ((newline_pos = incoming.find('\n')) != std::string::npos) {
                std::string line = incoming.substr(0, newline_pos);
                incoming.erase(0, newline_pos + 1);

                std::cout << "[C++ Client] Received: " << line << "\n";
                // Simple parsing for demo: check if it's an action
                if (line.find("\"type\":\"action\"") != std::string::npos) {
                    // Extract id (e.g. "id":"act_1")
                    size_t id_pos = line.find("\"id\":\"");
                    if (id_pos != std::string::npos) {
                        size_t id_end = line.find("\"", id_pos + 6);
                        std::string action_id = line.substr(id_pos + 6, id_end - (id_pos + 6));

                        std::cout << "[C++ Client] Processing action " << action_id << "...\n";
                        std::this_thread::sleep_for(std::chrono::milliseconds(100));

                        // Send success response
                        std::string response = "{\"type\":\"action_result\",\"id\":\"" + action_id + "\",\"success\":true}\n";
                        send(sock, response.c_str(), response.length(), 0);
                        std::cout << "[C++ Client] Sent success response for action " << action_id << "\n";
                    }
                }
            }
        }
    });

    // Send a perception
    std::this_thread::sleep_for(std::chrono::seconds(1));
    std::cout << "[C++ Client] Sending perception: test_percept\n";
    std::string percept_msg = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}\n";
    send(sock, percept_msg.c_str(), percept_msg.length(), 0);

    receiver.join();
    close(sock);
    return 0;
}
