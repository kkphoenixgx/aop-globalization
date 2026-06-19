import Foundation
import Network

public class BdiClient {
    private var connection: NWConnection
    private let queue = DispatchQueue(label: "panteao-client-queue")
    private var actionHandlers: [String: ([String], @escaping (Bool) -> Void) -> Void] = [:]
    private var buffer = Data()

    public init(host: String = "127.0.0.1", port: Int = 44444) {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        self.connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
    }

    public func connect(completion: @escaping (Bool) -> Void) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.startReceiver()
                completion(true)
            case .failed(_):
                completion(false)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    public func registerAction(name: String, handler: @escaping ([String], @escaping (Bool) -> Void) -> Void) {
        actionHandlers[name] = handler
    }

    public func sendPerception(action: String, perception: String) {
        let payload = "{\"type\":\"perception\",\"action\":\"\(action)\",\"perception\":\"\(perception)\"}\n"
        connection.send(content: payload.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }

    private func sendActionResult(id: String, success: Bool) {
        let payload = "{\"type\":\"action_result\",\"id\":\"\(id)\",\"success\":\(success)}\n"
        connection.send(content: payload.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }

    private func startReceiver() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            if error == nil && !isComplete {
                self.startReceiver()
            }
        }
    }

    private func processBuffer() {
        while let newlineIndex = buffer.firstIndex(of: 10) { // 10 is ASCII for '\n'
            let lineData = buffer.subdata(in: 0..<newlineIndex)
            buffer.removeSubrange(0...newlineIndex)

            if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                handleLine(line)
            }
        }
    }

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "action",
              let actionId = json["id"] as? String,
              let rawAction = json["action"] as? String else {
            return
        }

        let (name, args) = parseAction(rawAction)
        if let handler = actionHandlers[name] {
            handler(args) { success in
                self.sendActionResult(id: actionId, success: success)
            }
        } else {
            self.sendActionResult(id: actionId, success: true)
        }
    }

    private func parseAction(_ actionStr: String) -> (String, [String]) {
        guard let parenIdx = actionStr.firstIndex(of: "(") else {
            return (actionStr.trimmingCharacters(in: .whitespacesAndNewlines), [])
        }
        let name = String(actionStr[..<parenIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rparen = actionStr.lastIndex(of: ")"), rparen > parenIdx else {
            return (name, [])
        }
        let startArgs = actionStr.index(after: parenIdx)
        let argsStr = String(actionStr[startArgs..<rparen])
        
        var args: [String] = []
        var current = ""
        var insideQuotes = false
        
        for char in argsStr {
            if char == "\"" {
                insideQuotes = !insideQuotes
            } else if char == "," && !insideQuotes {
                args.append(cleanArg(current))
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            args.append(cleanArg(current))
        }
        return (name, args)
    }

    private func cleanArg(_ arg: String) -> String {
        return arg.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
    }

    public func close() {
        connection.cancel()
    }
}
