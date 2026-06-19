#include "panteao_client.h"
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sstream>
#include <cstring>
#include <iostream>

namespace panteao {

BdiClient::BdiClient() : socketFd(-1), running(false) {}

BdiClient::~BdiClient() {
    close();
}

bool BdiClient::connect(const std::string& host, int port) {
    socketFd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (socketFd < 0) return false;

    sockaddr_in servAddr;
    std::memset(&servAddr, 0, sizeof(servAddr));
    servAddr.sin_family = AF_INET;
    servAddr.sin_port = htons(port);
    if (inet_pton(AF_INET, host.c_str(), &servAddr.sin_addr) <= 0) return false;

    if (::connect(socketFd, (struct sockaddr*)&servAddr, sizeof(servAddr)) < 0) {
        return false;
    }

    running = true;
    listenerThread = std::thread(&BdiClient::listenLoop, this);
    return true;
}

bool BdiClient::sendPerception(const std::string& action, const std::string& perception) {
    std::ostringstream ss;
    ss << "{\"type\":\"perception\",\"action\":\"" << action << "\",\"perception\":\"" << perception << "\"}\n";
    std::string payload = ss.str();
    
    std::lock_guard<std::mutex> lock(writeMutex);
    if (socketFd < 0) return false;
    return ::write(socketFd, payload.c_str(), payload.length()) >= 0;
}

void BdiClient::registerAction(const std::string& actionName, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)> callback) {
    handlers[actionName] = callback;
}

void BdiClient::sendActionResult(const std::string& actionId, bool success) {
    std::ostringstream ss;
    ss << "{\"type\":\"action_result\",\"id\":\"" << actionId << "\",\"success\":" << (success ? "true" : "false") << "}\n";
    std::string payload = ss.str();

    std::lock_guard<std::mutex> lock(writeMutex);
    if (socketFd >= 0) {
        ::write(socketFd, payload.c_str(), payload.length());
    }
}

void BdiClient::close() {
    running = false;
    if (socketFd >= 0) {
        ::shutdown(socketFd, SHUT_RDWR);
        ::close(socketFd);
        socketFd = -1;
    }
    if (listenerThread.joinable()) {
        listenerThread.join();
    }
}

void BdiClient::listenLoop() {
    char buf[4096];
    int total = 0;
    while (running) {
        int n = ::recv(socketFd, buf + total, sizeof(buf) - total - 1, 0);
        if (n <= 0) break;
        total += n;
        buf[total] = '\0';

        char *line_start = buf;
        char *newline;
        while ((newline = std::strchr(line_start, '\n')) != nullptr) {
            *newline = '\0';
            std::string line(line_start);

            if (line.find("\"type\":\"action\"") != std::string::npos) {
                std::string actionId = "";
                std::string rawAction = "";

                size_t id_pos = line.find("\"id\":\"");
                if (id_pos != std::string::npos) {
                    id_pos += 6;
                    size_t id_end = line.find('"', id_pos);
                    if (id_end != std::string::npos) {
                        actionId = line.substr(id_pos, id_end - id_pos);
                    }
                }

                size_t act_pos = line.find("\"action\":\"");
                if (act_pos != std::string::npos) {
                    act_pos += 10;
                    size_t act_end = line.find('"', act_pos);
                    if (act_end != std::string::npos) {
                        rawAction = line.substr(act_pos, act_end - act_pos);
                    }
                }

                if (!actionId.empty() && !rawAction.empty()) {
                    auto parsed = parseAction(rawAction);
                    auto handler_it = handlers.find(parsed.first);
                    if (handler_it != handlers.end()) {
                        auto respond = [this, actionId](bool success) {
                            sendActionResult(actionId, success);
                        };
                        handler_it->second(parsed.second, respond);
                    } else {
                        sendActionResult(actionId, true);
                    }
                }
            }
            line_start = newline + 1;
        }

        int remaining = total - (line_start - buf);
        if (remaining > 0 && line_start != buf) {
            std::memmove(buf, line_start, remaining);
            total = remaining;
        } else {
            total = 0;
        }
    }
}

std::pair<std::string, std::vector<std::string>> BdiClient::parseAction(const std::string& actionStr) {
    size_t parenIdx = actionStr.find('(');
    if (parenIdx == std::string::npos) {
        return {actionStr, {}};
    }
    std::string name = actionStr.substr(0, parenIdx);
    // trim name
    name.erase(0, name.find_first_not_of(" \t\r\n"));
    name.erase(name.find_last_not_of(" \t\r\n") + 1);

    size_t rparen = actionStr.rfind(')');
    if (rparen == std::string::npos || rparen <= parenIdx + 1) {
        return {name, {}};
    }

    std::string argsStr = actionStr.substr(parenIdx + 1, rparen - parenIdx - 1);
    std::vector<std::string> args;
    std::string current = "";
    bool insideQuotes = false;

    for (char c : argsStr) {
        if (c == '"') {
            insideQuotes = !insideQuotes;
        } else if (c == ',' && !insideQuotes) {
            args.push_back(cleanArg(current));
            current = "";
        } else {
            current.push_back(c);
        }
    }
    if (!current.empty()) {
        args.push_back(cleanArg(current));
    }
    return {name, args};
}

std::string BdiClient::cleanArg(const std::string& arg) {
    std::string res = arg;
    res.erase(0, res.find_first_not_of(" \t\r\n\""));
    res.erase(res.find_last_not_of(" \t\r\n\"") + 1);
    return res;
}

}
