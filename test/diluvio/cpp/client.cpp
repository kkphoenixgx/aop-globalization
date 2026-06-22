// ============================================================================
// Operação Dilúvio — O Controlo Físico das Comportas
// C++ gate controller: threads + chrono timing over TCP IPC
// ============================================================================

#include <iostream>
#include <string>
#include <thread>
#include <atomic>
#include <chrono>
#include <cstring>
#include <sstream>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
static constexpr const char* ENGINE_HOST = "127.0.0.1";
static constexpr int         ENGINE_PORT = 44444;
static constexpr int         TIMEOUT_SEC = 5;

static const std::string PERCEPTION_MSG =
    "{\"type\":\"message\",\"performative\":\"tell\",\"sender\":\"external\",\"receiver\":\"orquestrador\",\"content\":\"gate_pressure(gate_02,90)\"}\n";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
static std::string build_action_result(const std::string& id) {
    return R"({"type":"action_result","id":")" + id + R"(","success":true})" + "\n";
}

// Minimal JSON value extractor — finds "key":"value" and returns value.
static std::string json_value(const std::string& json, const std::string& key) {
    std::string needle = "\"" + key + "\":\"";
    auto pos = json.find(needle);
    if (pos == std::string::npos) return "";
    pos += needle.size();
    auto end = json.find('"', pos);
    if (end == std::string::npos) return "";
    return json.substr(pos, end - pos);
}

// ---------------------------------------------------------------------------
// Receiver thread
// ---------------------------------------------------------------------------
struct ReceiverCtx {
    int                  sockfd;
    std::atomic<bool>&   action_handled;
    std::string          action_name;
    std::string          action_id;
};

static void receiver_thread(ReceiverCtx ctx) {
    char buf[4096];
    std::string buffer;

    while (!ctx.action_handled.load()) {
        ssize_t n = ::recv(ctx.sockfd, buf, sizeof(buf) - 1, 0);
        if (n <= 0) break;
        buf[n] = '\0';
        buffer.append(buf);

        // Process complete lines
        std::string::size_type nl;
        while ((nl = buffer.find('\n')) != std::string::npos) {
            std::string line = buffer.substr(0, nl);
            buffer.erase(0, nl + 1);

            if (line.empty()) continue;

            std::string type = json_value(line, "type");
            if (type == "action") {
                ctx.action_id   = json_value(line, "id");
                ctx.action_name = json_value(line, "action");

                std::cout << "[DILUVIO] Action received  : " << ctx.action_name << "\n";
                std::cout << "[DILUVIO] Action ID        : " << ctx.action_id   << "\n";

                // Send result back on same socket
                std::string reply = build_action_result(ctx.action_id);
                ::send(ctx.sockfd, reply.c_str(), reply.size(), 0);

                std::cout << "[DILUVIO] Action result sent (success=true)\n";
                ctx.action_handled.store(true);
                return;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
int main() {
    using clock = std::chrono::steady_clock;

    std::cout << "============================================================\n";
    std::cout << " Operação Dilúvio — O Controlo Físico das Comportas (C++)\n";
    std::cout << "============================================================\n";

    auto t_start = clock::now();

    // -- Create socket -------------------------------------------------------
    int sockfd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        std::cerr << "[DILUVIO] ERROR: socket creation failed\n";
        return 1;
    }

    // Set receive timeout
    struct timeval tv;
    tv.tv_sec  = TIMEOUT_SEC;
    tv.tv_usec = 0;
    ::setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    // -- Connect to engine ---------------------------------------------------
    struct sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port   = htons(ENGINE_PORT);
    ::inet_pton(AF_INET, ENGINE_HOST, &addr.sin_addr);

    auto t_conn_start = clock::now();

    if (::connect(sockfd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        std::cerr << "[DILUVIO] ERROR: connection to " << ENGINE_HOST
                  << ":" << ENGINE_PORT << " failed\n";
        ::close(sockfd);
        return 1;
    }

    auto t_conn_end = clock::now();
    std::cout << "[DILUVIO] Connected to engine at "
              << ENGINE_HOST << ":" << ENGINE_PORT << "\n";

    // -- Wait for engine readiness -------------------------------------------
    std::cout << "[DILUVIO] Waiting 1s for engine readiness...\n";
    std::this_thread::sleep_for(std::chrono::seconds(1));

    // -- Send perception -----------------------------------------------------
    auto t_send = clock::now();

    std::cout << "[DILUVIO] Sending perception: gate_pressure(gate_02,90)\n";
    ssize_t sent = ::send(sockfd, PERCEPTION_MSG.c_str(), PERCEPTION_MSG.size(), 0);
    if (sent <= 0) {
        std::cerr << "[DILUVIO] ERROR: failed to send perception\n";
        ::close(sockfd);
        return 1;
    }

    // -- Launch receiver thread ----------------------------------------------
    std::atomic<bool> action_handled{false};
    ReceiverCtx ctx{sockfd, action_handled, "", ""};

    std::thread rx(receiver_thread, ctx);

    // -- Wait for completion or timeout --------------------------------------
    auto deadline = clock::now() + std::chrono::seconds(TIMEOUT_SEC);
    while (!action_handled.load() && clock::now() < deadline) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    auto t_end = clock::now();

    if (rx.joinable()) rx.join();

    // -- Report metrics ------------------------------------------------------
    auto ms = [](auto d) {
        return std::chrono::duration_cast<std::chrono::microseconds>(d).count() / 1000.0;
    };

    std::cout << "\n";
    std::cout << "------------------------------------------------------------\n";
    std::cout << " Timing Metrics\n";
    std::cout << "------------------------------------------------------------\n";
    std::cout << " Connection   : " << ms(t_conn_end - t_conn_start) << " ms\n";
    std::cout << " Send → Reply : " << ms(t_end - t_send)           << " ms\n";
    std::cout << " Total elapsed: " << ms(t_end - t_start)          << " ms\n";
    std::cout << "------------------------------------------------------------\n";

    if (action_handled.load()) {
        std::cout << "\n[DILUVIO] SUCCESS\n";
    } else {
        std::cerr << "\n[DILUVIO] FAILURE: timed out waiting for action\n";
        ::close(sockfd);
        return 1;
    }

    ::close(sockfd);
    return 0;
}
