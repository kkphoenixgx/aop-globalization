import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

public typealias ActionCallback = ([String], @escaping (Bool) -> Void) -> Void

public class BdiClient {
    private var sockFd: Int32 = -1
    private var actionHandlers: [String: ActionCallback] = [:]
    private var process: Process?
    private let host: String
    private var port: Int
    private var running = true

    public init(host: String = "127.0.0.1", port: Int = 44444, project: String? = nil) {
        self.host = host
        self.port = port
        if let proj = project {
            if self.port == 0 { self.port = BdiClient.getFreePort() }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: BdiClient.findBinary())
            proc.arguments = [proj, "--port", String(self.port)]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            self.process = proc
            usleep(800000)
        } else {
            if self.port == 0 { self.port = 44444 }
        }
    }

    private static func getFreePort() -> Int {
        #if canImport(Glibc)
        let fd = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { return 44444 }
        defer {
            #if canImport(Glibc)
            Glibc.close(fd)
            #else
            Darwin.close(fd)
            #endif
        }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = in_addr_t(0)
        addr.sin_port = 0
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        _ = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &addrLen)
            }
        }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    private static func findBinary() -> String {
        let binName = "panteao-engine"
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        if fm.fileExists(atPath: "\(cwd)/\(binName)") { return "\(cwd)/\(binName)" }
        if fm.fileExists(atPath: "\(cwd)/bin/\(binName)") { return "\(cwd)/bin/\(binName)" }
        return binName
    }

    public func connect(completion: @escaping (Bool) -> Void) {
        #if canImport(Glibc)
        sockFd = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        sockFd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard sockFd >= 0 else {
            completion(false)
            return
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                #if canImport(Glibc)
                Glibc.connect(sockFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                #else
                Darwin.connect(sockFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                #endif
            }
        }

        guard result == 0 else {
            completion(false)
            return
        }

        // Handshake: read until mas_ready
        while true {
            guard let line = readLineFromSocket() else {
                completion(false)
                return
            }
            if line.contains("\"type\":\"mas_ready\"") {
                break
            }
        }

        // Start listener thread
        DispatchQueue.global().async { [weak self] in
            self?.listenLoop()
        }

        completion(true)
    }

    private func readLineFromSocket() -> String? {
        var result = ""
        var buf = [UInt8](repeating: 0, count: 1)
        while true {
            let n = recv(sockFd, &buf, 1, 0)
            if n <= 0 { return nil }
            let ch = Character(UnicodeScalar(buf[0]))
            if ch == "\n" { return result }
            result.append(ch)
        }
    }

    private func listenLoop() {
        while running {
            guard let line = readLineFromSocket() else { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            handleLine(trimmed)
        }
    }

    private func handleLine(_ line: String) {
        guard line.contains("\"type\":\"action\"") else { return }

        let actionId = extractJsonValue(line, key: "id") ?? ""
        let rawAction = extractJsonValue(line, key: "action") ?? ""

        let (name, args) = parseAction(rawAction)
        if let handler = actionHandlers[name] {
            handler(args) { [weak self] success in
                self?.sendActionResult(actionId, success: success)
            }
        } else {
            sendActionResult(actionId, success: true)
        }
    }

    private func extractJsonValue(_ json: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: json, range: NSRange(json.startIndex..., in: json)),
              let range = Range(match.range(at: 1), in: json) else { return nil }
        return String(json[range])
    }

    private func parseAction(_ actionStr: String) -> (String, [String]) {
        guard let parenIdx = actionStr.firstIndex(of: "(") else {
            return (actionStr.trimmingCharacters(in: .whitespaces), [])
        }
        let name = String(actionStr[actionStr.startIndex..<parenIdx]).trimmingCharacters(in: .whitespaces)
        guard let endParen = actionStr.lastIndex(of: ")") else {
            return (name, [])
        }
        let argsStr = String(actionStr[actionStr.index(after: parenIdx)..<endParen])

        var args: [String] = []
        var current = ""
        var insideQuotes = false
        var depthBrackets = 0
        var depthParens = 0

        for c in argsStr {
            if c == "\"" {
                insideQuotes = !insideQuotes
                current.append(c)
            } else if !insideQuotes && c == "[" {
                depthBrackets += 1
                current.append(c)
            } else if !insideQuotes && c == "]" {
                depthBrackets -= 1
                current.append(c)
            } else if !insideQuotes && c == "(" {
                depthParens += 1
                current.append(c)
            } else if !insideQuotes && c == ")" {
                depthParens -= 1
                current.append(c)
            } else if c == "," && !insideQuotes && depthBrackets == 0 && depthParens == 0 {
                args.append(cleanArg(current))
                current = ""
            } else {
                current.append(c)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(cleanArg(current))
        }
        return (name, args)
    }

    private func cleanArg(_ arg: String) -> String {
        let s = arg.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    public func sendMsg(_ performative: String, _ sender: String, _ receiver: String, _ content: String) {
        let json = "{\"type\":\"message\",\"performative\":\"\(performative)\",\"sender\":\"\(sender)\",\"receiver\":\"\(receiver)\",\"content\":\"\(content)\"}\n"
        sendRaw(json)
    }

    public func sendPerception(_ action: String, _ perception: String) {
        let json = "{\"type\":\"perception\",\"action\":\"\(action)\",\"perception\":\"\(perception)\"}\n"
        sendRaw(json)
    }

    public func registerAction(_ actionName: String, handler: @escaping ActionCallback) {
        actionHandlers[actionName] = handler
    }

    private func sendActionResult(_ id: String, success: Bool) {
        let json = "{\"type\":\"action_result\",\"id\":\"\(id)\",\"success\":\(success)}\n"
        sendRaw(json)
    }

    private func sendRaw(_ str: String) {
        let data = Array(str.utf8)
        _ = send(sockFd, data, data.count, 0)
    }

    public func close() {
        running = false
        if sockFd >= 0 {
            shutdown(sockFd, Int32(SHUT_RDWR))
            #if canImport(Glibc)
            Glibc.close(sockFd)
            #else
            Darwin.close(sockFd)
            #endif
            sockFd = -1
        }
        if let proc = process {
            proc.terminate()
        }
    }
}
