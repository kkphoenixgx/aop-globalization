import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

print("[DILUVIO] Swift client starting")
Thread.sleep(forTimeInterval: 1)

let client = BdiClient(host: "127.0.0.1", port: 44444)
var actionHandled = false

client.registerAction("open_gate") { args, respond in
    print("[DILUVIO] Action handled: open_gate")
    if !args.isEmpty {
        print("[DILUVIO] Args: \(args[0])")
    }
    respond(true)
    actionHandled = true
}

let semaphore = DispatchSemaphore(value: 0)

client.connect { success in
    guard success else {
        print("[DILUVIO] FAILURE")
        exit(1)
    }
    print("[DILUVIO] Connected!")
    client.sendMsg("tell", "external", "orquestrador", "gate_pressure(gate_5,88)")
    semaphore.signal()
}

semaphore.wait()

// Wait up to 5 seconds for the action
for _ in 0..<50 {
    if actionHandled { break }
    Thread.sleep(forTimeInterval: 0.1)
}

client.close()

if actionHandled {
    print("[DILUVIO] SUCCESS")
    exit(0)
} else {
    print("[DILUVIO] TIMEOUT")
    exit(1)
}
