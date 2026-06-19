<?php

namespace Panteao;

class BdiClient {
    private $socket;
    private $handlers = [];

    public function __construct(string $host = '127.0.0.1', int $port = 44444) {
        $this->socket = fsockopen($host, $port, $errno, $errstr, 5);
        if (!$this->socket) {
            throw new \Exception("Could not connect to Panteao: $errstr");
        }
    }

    public function sendPerception(string $action, string $perception): void {
        $payload = json_encode([
            'type' => 'perception',
            'action' => $action,
            'perception' => $perception
        ]) . "\n";
        fwrite($this->socket, $payload);
    }

    public function registerAction(string $actionName, callable $callback): void {
        $this->handlers[$actionName] = $callback;
    }

    public function processActions(float $timeoutSeconds = 5.0): void {
        stream_set_timeout($this->socket, (int)$timeoutSeconds, (int)(($timeoutSeconds - (int)$timeoutSeconds) * 1000000));
        while (!feof($this->socket)) {
            $line = fgets($this->socket);
            if ($line === false) {
                break;
            }
            $line = trim($line);
            if (empty($line)) continue;
            
            $msg = json_decode($line, true);
            if ($msg && isset($msg['type']) && $msg['type'] === 'action') {
                $rawAction = $msg['action'];
                $id = $msg['id'];
                $parsed = $this->parseAction($rawAction);
                
                $handler = $this->handlers[$parsed['name']] ?? null;
                if ($handler) {
                    $respond = function(bool $success) use ($id) {
                        $this->sendActionResult($id, $success);
                    };
                    $handler($parsed['args'], $respond);
                } else {
                    $this->sendActionResult($id, true);
                }
            }
        }
    }

    private function parseAction(string $actionStr): array {
        $parenIdx = strpos($actionStr, '(');
        if ($parenIdx === false) {
            return ['name' => trim($actionStr), 'args' => []];
        }
        $name = trim(substr($actionStr, 0, $parenIdx));
        $argsStr = substr($actionStr, $parenIdx + 1, strrpos($actionStr, ')') - $parenIdx - 1);
        
        $args = [];
        $current = '';
        $insideQuotes = false;
        for ($i = 0; $i < strlen($argsStr); $i++) {
            $char = $argsStr[$i];
            if ($char === '"') {
                $insideQuotes = !$insideQuotes;
            } else if ($char === ',' && !$insideQuotes) {
                $args[] = $this->cleanArg($current);
                $current = '';
            } else {
                $current .= $char;
            }
        }
        if (strlen(trim($current)) > 0) {
            $args[] = $this->cleanArg($current);
        }
        return ['name' => $name, 'args' => $args];
    }

    private function cleanArg(string $arg): string {
        return trim($arg, ' \t\n\r\0\x0B"');
    }

    private function sendActionResult(string $id, bool $success): void {
        $payload = json_encode([
            'type' => 'action_result',
            'id' => $id,
            'success' => $success
        ]) . "\n";
        fwrite($this->socket, $payload);
    }

    public function close(): void {
        fclose($this->socket);
    }
}
