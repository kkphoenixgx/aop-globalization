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

class Panteao {
public:
    Panteao();
    ~Panteao();

    bool connect(const std::string& host, int port, const std::string& project = "");
    bool sendMsg(const std::string& performative, const std::string& sender, const std::string& receiver, const std::string& content);
bool sendPerception(const std::string& action, const std::string& perception);
    void registerAction(const std::string& actionName, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)> callback);
    void close();
    void wait();

private:
    void listenLoop();
    void downloadEngine();
    void sendActionResult(const std::string& actionId, bool success);
    std::pair<std::string, std::vector<std::string>> parseAction(const std::string& actionStr);


    int socketFd;
    int enginePid;
    std::atomic<bool> running;
    std::thread listenerThread;
    std::thread stdoutThread;
    std::thread stderrThread;
    std::map<std::string, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)>> handlers;
    std::mutex writeMutex;
    std::string sdkVersion;
};

}

#endif
