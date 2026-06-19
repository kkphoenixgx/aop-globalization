<?php
$host = '127.0.0.1';
$port = 44444;
$start = microtime(true);

echo "[DILUVIO] PHP client starting\n";

$socket = fsockopen($host, $port, $errno, $errstr, 5);
if (!$socket) {
    echo "[DILUVIO] FAILURE: $errstr ($errno)\n";
    exit(1);
}

echo "[DILUVIO] Connected in " . round((microtime(true) - $start) * 1000, 2) . "ms\n";
sleep(1);

$percept = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"shelter_needed(escola_01)\"}\n";
echo "[DILUVIO] Sending: $percept";
fwrite($socket, $percept);

while (!feof($socket)) {
    $line = fgets($socket);
    if ($line === false) continue;
    echo "[DILUVIO] Received: $line";
    if (strpos($line, '"type":"action"') !== false) {
        $msg = json_decode($line, true);
        $id = $msg['id'];
        $response = "{\"type\":\"action_result\",\"id\":\"$id\",\"success\":true}\n";
        echo "[DILUVIO] Sending result: $response";
        fwrite($socket, $response);
        echo "[DILUVIO] SUCCESS\n";
        break;
    }
}
fclose($socket);
?>
