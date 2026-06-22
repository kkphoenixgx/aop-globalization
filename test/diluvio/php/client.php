<?php
require_once __DIR__ . '/vendor/autoload.php';

use Panteao\BdiClient;

echo "[DILUVIO] PHP client starting\n";

$client = new BdiClient('127.0.0.1', 44444);

$client->registerAction('open_shelter', function($args, $respond) use ($client) {
    echo "[DILUVIO] Action handled: open_shelter\n";
    $respond(true);
    echo "[DILUVIO] SUCCESS\n";
    $client->close();
    exit(0);
});

try {
    echo "[DILUVIO] Connected!\n";
    $client->sendMsg('tell', 'external', 'orquestrador', 'shelter_needed(escolamunicipal)');

    $client->processActions(5.0);
    echo "[DILUVIO] TIMEOUT\n";
    $client->close();
    exit(1);
} catch (Exception $e) {
    echo "[DILUVIO] FAILURE: " . $e->getMessage() . "\n";
    exit(1);
}
