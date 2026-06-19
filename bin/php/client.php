<?php
$fp = fsockopen("127.0.0.1", 40000, $errno, $errstr, 30);
if ($fp) {
    fwrite($fp, json_encode(["type" => "perception", "action" => "add", "perception" => "test_percept"]) . "\n");
    fclose($fp);
}
?>