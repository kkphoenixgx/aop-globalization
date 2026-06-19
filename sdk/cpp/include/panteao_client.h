#ifndef PANTEAO_CLIENT_CPP_H
#define PANTEAO_CLIENT_CPP_H

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <thread>
#include <mutex>
#include <atomic>

namespace panteao {

class BdiClient {
public:
    BdiClient();
    ~BdiClient();

    bool connect(const std::string& host, int port);
    bool sendPerception(const std::string& action, const std::string& perception);
    void registerAction(const std::string& actionName, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)> callback);
    void close();

private:
    void listenLoop();
    void sendActionResult(const std::string& actionId, bool success);
    std::pair<std::string, std::vector<std::string>> parseAction(const std::string& actionStr);
    std::string cleanArg(const std::string& arg);

    int socketFd;
    std::atomic<bool> running;
    std::thread listenerThread;
    std::map<std::string, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)>> handlers;
    std::mutex writeMutex;
};

}

#endif
