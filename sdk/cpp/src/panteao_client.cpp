#include "panteao_client.h"
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sstream>
#include <cstring>
#include <iostream>
#include <signal.h>
#include <sys/wait.h>
#include <regex>
#include <cstdlib>

namespace panteao {

static void readLogs(int fd) {
    char buf[1024];
    std::string buffer;
    std::regex re("^\\[(.*?)\\]\\s(.*)");
    while (true) {
        int n = ::read(fd, buf, sizeof(buf) - 1);
        if (n <= 0) break;
        buf[n] = '\0';
        buffer += buf;
        size_t pos = 0;
        while ((pos = buffer.find('\n')) != std::string::npos) {
            std::string line = buffer.substr(0, pos);
            buffer.erase(0, pos + 1);
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.empty()) continue;
            
            std::smatch match;
            if (std::regex_match(line, match, re)) {
                std::string raw_name = match[1];
                size_t dot_pos = raw_name.find_last_of('.');
                std::string name = (dot_pos == std::string::npos) ? raw_name : raw_name.substr(dot_pos + 1);
                std::cout << "\033[36m[" << name << "]\033[0m " << match[2] << std::endl;
            } else {
                std::cout << "\033[36m[MAS]\033[0m " << line << std::endl;
            }
        }
    }
}

Panteao::Panteao() : socketFd(-1), enginePid(-1), running(false), sdkVersion("1.1.17") {}

Panteao::~Panteao() {
    close();
}

bool Panteao::connect(const std::string& host, int port, const std::string& project) {
    int actualPort = port;
    std::string actualHost = host.empty() ? "127.0.0.1" : host;

    if (!project.empty()) {
        if (access("panteao-engine", F_OK) == -1 && access("panteao-engine.exe", F_OK) == -1) {
            downloadEngine();
        }

        if (actualPort == 0) {
            // Find a free port (simplistic approach for now)
            struct sockaddr_in servAddr;
            int tempFd = ::socket(AF_INET, SOCK_STREAM, 0);
            std::memset(&servAddr, 0, sizeof(servAddr));
            servAddr.sin_family = AF_INET;
            servAddr.sin_addr.s_addr = htonl(INADDR_ANY);
            servAddr.sin_port = 0;
            if (::bind(tempFd, (struct sockaddr*)&servAddr, sizeof(servAddr)) == 0) {
                socklen_t len = sizeof(servAddr);
                if (::getsockname(tempFd, (struct sockaddr*)&servAddr, &len) == 0) {
                    actualPort = ntohs(servAddr.sin_port);
                }
            }
            ::close(tempFd);
            if (actualPort == 0) actualPort = 44444; // fallback
        }

        int pipe_out[2], pipe_err[2];
        pipe(pipe_out);
        pipe(pipe_err);

        enginePid = fork();
        if (enginePid == 0) {
            // Child process
            dup2(pipe_out[1], STDOUT_FILENO);
            dup2(pipe_err[1], STDERR_FILENO);
            ::close(pipe_out[0]); ::close(pipe_out[1]);
            ::close(pipe_err[0]); ::close(pipe_err[1]);

            std::string portStr = std::to_string(actualPort);
            execlp("./panteao-engine", "panteao-engine", project.c_str(), "--port", portStr.c_str(), (char*)NULL);
            execlp("panteao-engine", "panteao-engine", project.c_str(), "--port", portStr.c_str(), (char*)NULL);
            std::cerr << "Failed to start panteao-engine\n";
            _exit(1);
        } else if (enginePid < 0) {
            return false;
        }

        ::close(pipe_out[1]);
        ::close(pipe_err[1]);
        stdoutThread = std::thread(readLogs, pipe_out[0]);
        stderrThread = std::thread(readLogs, pipe_err[0]);

        usleep(800000); // 800ms wait
    } else {
        if (actualPort == 0) actualPort = 44444;
    }

    socketFd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (socketFd < 0) return false;

    sockaddr_in servAddr;
    std::memset(&servAddr, 0, sizeof(servAddr));
    servAddr.sin_family = AF_INET;
    servAddr.sin_port = htons(actualPort);
    if (inet_pton(AF_INET, actualHost.c_str(), &servAddr.sin_addr) <= 0) return false;

    if (::connect(socketFd, (struct sockaddr*)&servAddr, sizeof(servAddr)) < 0) {
        ::close(socketFd);
        socketFd = -1;
        return false;
    }

    // Handshake
    char buf[1024];
    std::string handshake_data;
    while (true) {
        int n = ::read(socketFd, buf, sizeof(buf));
        if (n <= 0) break;
        handshake_data.append(buf, n);
        if (handshake_data.find("\"type\":\"mas_ready\"") != std::string::npos) {
            break;
        }
    }

    running = true;
    listenerThread = std::thread(&Panteao::listenLoop, this);
    return true;
}

bool Panteao::sendMsg(const std::string& performative, const std::string& sender, const std::string& receiver, const std::string& content) {
    std::lock_guard<std::mutex> lock(writeMutex);
    std::ostringstream oss;
    oss << "{\"type\":\"message\",\"performative\":\"" << performative 
        << "\",\"sender\":\"" << sender 
        << "\",\"receiver\":\"" << receiver 
        << "\",\"content\":\"" << content << "\"}\n";
    std::string payload = oss.str();
    if (socketFd >= 0) {
        int total = 0;
        int len = payload.length();
        while (total < len) {
            int n = ::write(socketFd, payload.c_str() + total, len - total);
            if (n <= 0) return false;
            total += n;
        }
        return true;
    }
    return false;
}

bool Panteao::sendPerception(const std::string& action, const std::string& perception) {
    std::lock_guard<std::mutex> lock(writeMutex);
    std::ostringstream oss;
    oss << "{\"type\":\"perception\",\"action\":\"" << action << "\",\"perception\":\"" << perception << "\"}\n";
    std::string payload = oss.str();
    if (socketFd >= 0) {
        int total = 0;
        int len = payload.length();
        while (total < len) {
            int n = ::write(socketFd, payload.c_str() + total, len - total);
            if (n <= 0) return false;
            total += n;
        }
        return true;
    }
    return false;
}

void Panteao::registerAction(const std::string& actionName, std::function<void(const std::vector<std::string>& args, std::function<void(bool)> respond)> callback) {
    handlers[actionName] = callback;
}

void Panteao::sendActionResult(const std::string& actionId, bool success) {
    std::lock_guard<std::mutex> lock(writeMutex);
    std::ostringstream oss;
    oss << "{\"type\":\"action_result\",\"id\":\"" << actionId << "\",\"success\":" << (success ? "true" : "false") << "}\n";
    std::string payload = oss.str();
    if (socketFd >= 0) {
        int total = 0;
        int len = payload.length();
        while (total < len) {
            int n = ::write(socketFd, payload.c_str() + total, len - total);
            if (n <= 0) break;
            total += n;
        }
    }
}

void Panteao::close() {
    running = false;
    if (socketFd >= 0) {
        ::shutdown(socketFd, SHUT_RDWR);
        ::close(socketFd);
        socketFd = -1;
    }
    if (listenerThread.joinable()) {
        listenerThread.join();
    }
    if (enginePid > 0) {
        kill(enginePid, SIGKILL);
        waitpid(enginePid, nullptr, 0);
        enginePid = -1;
    }
    if (stdoutThread.joinable()) stdoutThread.join();
    if (stderrThread.joinable()) stderrThread.join();
}

void Panteao::wait() {
    while (running && listenerThread.joinable()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}

void Panteao::downloadEngine() {
    std::string osName, arch;
#if defined(_WIN32)
    osName = "win32";
    arch = "x64"; 
#elif defined(__APPLE__)
    osName = "darwin";
    #if defined(__aarch64__)
        arch = "arm64";
    #else
        arch = "x64";
    #endif
#else
    osName = "linux";
    #if defined(__aarch64__)
        arch = "arm64";
    #else
        arch = "x64";
    #endif
#endif

    std::string pkgName = "panteao-engine-" + osName + "-" + arch;
    std::string url = "https://registry.npmjs.org/" + pkgName + "/-/" + pkgName + "-" + sdkVersion + ".tgz";
    std::cout << "[Panteao] Downloading native engine for " << osName << "-" << arch << " (v" << sdkVersion << ")...\n";

#if defined(_WIN32)
    std::system(("curl -sL " + url + " -o panteao.tgz").c_str());
    std::system("tar -xf panteao.tgz package/bin/panteao-engine.exe");
    std::system("move package\\bin\\panteao-engine.exe panteao-engine.exe");
    std::system("rmdir /S /Q package");
    std::system("del panteao.tgz");
#else
    std::string cmd = "curl -sL " + url + " | tar -xz --strip-components=2 package/bin/panteao-engine";
    std::system(cmd.c_str());
#endif
    std::cout << "[Panteao] Engine downloaded successfully.\n";
}

void Panteao::listenLoop() {
    char buf[4096];
    int total = 0;

    while (running && socketFd >= 0) {
        int bytes_read = ::read(socketFd, buf + total, sizeof(buf) - total - 1);
        if (bytes_read <= 0) {
            break;
        }
        total += bytes_read;
        buf[total] = '\0';

        char* line_start = buf;
        char* newline;
        while ((newline = strchr(line_start, '\n')) != nullptr) {
            *newline = '\0';
            std::string line(line_start);
            if (line.find("\"type\":\"action\"") != std::string::npos) {
                std::string actionId;
                std::string rawAction;
                
                size_t idPos = line.find("\"id\":\"");
                if (idPos != std::string::npos) {
                    size_t idEnd = line.find("\"", idPos + 6);
                    if (idEnd != std::string::npos) {
                        actionId = line.substr(idPos + 6, idEnd - idPos - 6);
                    }
                }
                
                size_t actPos = line.find("\"action\":\"");
                if (actPos != std::string::npos) {
                    size_t actEnd = line.find("\"", actPos + 10);
                    if (actEnd != std::string::npos) {
                        rawAction = line.substr(actPos + 10, actEnd - actPos - 10);
                    }
                }

                if (!rawAction.empty()) {
                    auto [name, args] = parseAction(rawAction);
                    if (handlers.find(name) != handlers.end()) {
                        handlers[name](args, [this, actionId](bool success) {
                            sendActionResult(actionId, success);
                        });
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

static std::string cleanArg(const std::string& arg) {
    std::string s = arg;
    s.erase(0, s.find_first_not_of(" \t\r\n"));
    s.erase(s.find_last_not_of(" \t\r\n") + 1);
    if (s.length() >= 2 && s.front() == '"' && s.back() == '"') {
        s = s.substr(1, s.length() - 2);
    }
    return s;
}

std::pair<std::string, std::vector<std::string>> Panteao::parseAction(const std::string& actionStr) {
    size_t parenIdx = actionStr.find('(');
    if (parenIdx == std::string::npos) {
        return {actionStr, {}};
    }
    std::string name = actionStr.substr(0, parenIdx);
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
    int depthBrackets = 0;
    int depthParens = 0;

    for (char c : argsStr) {
        if (c == '"') {
            insideQuotes = !insideQuotes;
            current.push_back(c);
        } else if (!insideQuotes && c == '[') {
            depthBrackets++;
            current.push_back(c);
        } else if (!insideQuotes && c == ']') {
            depthBrackets--;
            current.push_back(c);
        } else if (!insideQuotes && c == '(') {
            depthParens++;
            current.push_back(c);
        } else if (!insideQuotes && c == ')') {
            depthParens--;
            current.push_back(c);
        } else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0) {
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

}
