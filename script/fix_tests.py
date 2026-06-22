import os
import re

updates = {
    "objc": {
        "file": "test/diluvio/objc/client.m",
        "action": "send_push_notification",
        "perception": "evacuation_order(\"zone6\")",
        "method": "[client sendPerceptionWithAction:@\"add\" perception:@\"evacuation_order(zone6)\"];",
        "replace_send": "\\[client sendMsg.*"
    },
    "swift": {
        "file": "test/diluvio/swift/client.swift",
        "action": "send_push_notification",
        "perception": "evacuation_order(\"zone7\")",
        "method": "client.sendPerception(action: \"add\", perception: \"evacuation_order(\\\"zone7\\\")\")",
        "replace_send": "client\\.sendMsg.*"
    },
    "java": {
        "file": "test/diluvio/java/Client.java",
        "action": "liberate_emergency_funds",
        "perception": "emergency_declared(\"zone1\")",
        "method": "client.sendPerception(\"add\", \"emergency_declared(\\\"zone1\\\")\");",
        "replace_send": "client\\.sendMsg.*"
    }
}

for lang, data in updates.items():
    if not os.path.exists(data['file']):
        print(f"Skipping {lang}, file not found")
        continue
    
    with open(data['file'], 'r') as f:
        content = f.read()
    
    content = re.sub(r'(register_?action\s*\(\s*client\s*,\s*|register_?action\s*\(\s*|registerAction\s*\(\s*)["\'][a-zA-Z0-9_]+["\']', r'\g<1>"' + data['action'] + '"', content)
    content = re.sub(r'registerAction:@["\'][a-zA-Z0-9_]+["\']', 'registerAction:@"' + data['action'] + '"', content)

    content = re.sub(data['replace_send'], data['method'], content)
    
    with open(data['file'], 'w') as f:
        f.write(content)
        
    print(f"Patched {lang} test.")

