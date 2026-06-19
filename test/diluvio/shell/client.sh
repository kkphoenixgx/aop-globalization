#!/bin/bash
set -e

HOST="127.0.0.1"
PORT=44444

echo "[DILUVIO] Shell/Bash client starting"

# Open TCP connection on FD 3
exec 3<>/dev/tcp/$HOST/$PORT

echo "[DILUVIO] Connected!"
sleep 1

# Send perception
PERCEPT='{"type":"perception","action":"add","perception":"high_latency(750)"}'
echo "[DILUVIO] Sending: $PERCEPT"
echo "$PERCEPT" >&3

# Read response line by line
while read -r line <&3; do
    echo "[DILUVIO] Received: $line"
    if [[ "$line" == *'"type":"action"'* ]]; then
        # Parse action id using bash regex
        if [[ "$line" =~ \"id\":\"([^\"]+)\" ]]; then
            ACTION_ID="${BASH_REMATCH[1]}"
            RESPONSE="{\"type\":\"action_result\",\"id\":\"$ACTION_ID\",\"success\":true}"
            echo "[DILUVIO] Sending result: $RESPONSE"
            echo "$RESPONSE" >&3
            echo "[DILUVIO] SUCCESS"
            break
        fi
    fi
done

# Close FD 3
exec 3>&-
exec 3<&-
exit 0
