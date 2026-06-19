import Glibc
import Foundation

let host = "127.0.0.1"
let port: UInt16 = 44444

print("[DILUVIO] Swift client starting")

let sock = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
if sock < 0 {
    print("[DILUVIO] FAILURE: socket creation failed")
    exit(1)
}

var serverAddr = sockaddr_in()
serverAddr.sin_family = sa_family_t(AF_INET)
serverAddr.sin_port = port.bigEndian
inet_pton(AF_INET, host, &serverAddr.sin_addr)

let connectResult = withUnsafePointer(to: &serverAddr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
}

if connectResult < 0 {
    print("[DILUVIO] FAILURE: connection failed")
    exit(1)
}

print("[DILUVIO] Connected!")
sleep(1)

let percept = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"evacuation_order(zona_sul)\"}\n"
percept.withCString { ptr in
    _ = send(sock, ptr, strlen(ptr), 0)
}
print("[DILUVIO] Sent perception")

var buffer = [CChar](repeating: 0, count: 2048)
let bytesRead = recv(sock, &buffer, 2047, 0)
if bytesRead > 0 {
    buffer[bytesRead] = 0
    let response = String(cString: buffer)
    print("[DILUVIO] Received: \(response)")
    
    if response.contains("\"type\":\"action\"") {
        // Extract id manually
        let parts = response.components(separatedBy: "\"id\":\"")
        if parts.count > 1 {
            let id = parts[1].components(separatedBy: "\"")[0]
            let actionResult = "{\"type\":\"action_result\",\"id\":\"\(id)\",\"success\":true}\n"
            actionResult.withCString { ptr in
                _ = send(sock, ptr, strlen(ptr), 0)
            }
            print("[DILUVIO] Action result sent")
            print("[DILUVIO] SUCCESS")
        }
    }
}

close(sock)
exit(0)
