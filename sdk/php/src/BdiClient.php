<?php

namespace Panteao;

class BdiClient {
    const VERSION = '1.1.17';

    private static function downloadEngine(string $binPath): void {
        $isWin = (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN');
        $isMac = (PHP_OS === 'Darwin');
        $osName = $isWin ? 'win32' : ($isMac ? 'darwin' : 'linux');
        $arch = (php_uname('m') === 'aarch64' || php_uname('m') === 'arm64') ? 'arm64' : 'x64';
        
        $pkgName = "panteao-engine-$osName-$arch";
        $version = self::VERSION;
        $url = "https://registry.npmjs.org/$pkgName/-/$pkgName-$version.tgz";
        
        echo "\033[36m[Panteao]\033[0m Downloading native engine for $osName-$arch (v$version)...\n";
        
        $tgzData = @file_get_contents($url);
        if ($tgzData === false) throw new \Exception("Failed to download engine from $url");
        
        $tmpTgz = tempnam(sys_get_temp_dir(), 'engine') . '.tgz';
        file_put_contents($tmpTgz, $tgzData);
        
        try {
            $phar = new \PharData($tmpTgz);
            $extracted = false;
            foreach (new \RecursiveIteratorIterator($phar) as $file) {
                $filename = $file->getFilename();
                if ($filename === 'panteao-engine' || $filename === 'panteao-engine.exe') {
                    $dir = dirname($binPath);
                    if (!is_dir($dir)) mkdir($dir, 0777, true);
                    copy($file->getPathname(), $binPath);
                    chmod($binPath, 0755);
                    $extracted = true;
                    break;
                }
            }
            if (!$extracted) throw new \Exception("Binary not found in tarball");
        } finally {
            unlink($tmpTgz);
        }
    }

    private $socket;
    private $handlers = [];
    private $process;

    private static function getFreePort(): int {
        $server = stream_socket_server("tcp://127.0.0.1:0", $errno, $errstr);
        if (!$server) return 44444;
        $name = stream_socket_get_name($server, false);
        fclose($server);
        if ($name) {
            $parts = explode(':', $name);
            return (int)end($parts);
        }
        return 44444;
    }

    private static function findBinary(): string {
        $isWin = (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN');
        $binName = $isWin ? 'panteao-engine.exe' : 'panteao-engine';
        
        $currentDir = __DIR__;
        $cand1 = $currentDir . '/' . $binName;
        if (file_exists($cand1)) return $cand1;
        $cand2 = $currentDir . '/bin/' . $binName;
        if (file_exists($cand2)) return $cand2;
        
        $cwd = getcwd();
        $cand3 = $cwd . '/' . $binName;
        if (file_exists($cand3)) return $cand3;
        $cand4 = $cwd . '/bin/' . $binName;
        if (file_exists($cand4)) return $cand4;
        
        return $binName;
    }

    public function __construct(string $host = '127.0.0.1', int $port = 0, ?string $project = null) {
        $actualHost = empty($host) ? '127.0.0.1' : $host;
        if ($project !== null) {
            if ($port === 0) {
                $port = self::getFreePort();
            }
            $bin = self::findBinary();
            if (!file_exists($bin)) {
                $currentDir = __DIR__;
                $bin = $currentDir . '/' . (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN' ? 'panteao-engine.exe' : 'panteao-engine');
                self::downloadEngine($bin);
            }
            $descriptorspec = [
                0 => ["pipe", "r"],
                1 => ["file", "php://stdout", "a"],
                2 => ["file", "php://stderr", "a"]
            ];
            if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
                $descriptorspec[1] = ["file", "NUL", "a"];
                $descriptorspec[2] = ["file", "NUL", "a"];
            }
            $this->process = proc_open([$bin, $project, '--port', (string)$port], $descriptorspec, $pipes);
            usleep(800000);
        } else if ($port === 0) {
            $port = 44444;
        }

        $this->socket = fsockopen($actualHost, $port, $errno, $errstr, 5);
        if (!$this->socket) {
            if ($this->process) proc_terminate($this->process);
            throw new \Exception("Could not connect to Panteao: $errstr");
        }

        while (!feof($this->socket)) {
            $line = fgets($this->socket);
            if ($line === false) {
                if ($this->process) proc_terminate($this->process);
                throw new \Exception("Connection closed during handshake");
            }
            if (str_contains($line, '"type":"mas_ready"')) {
                break;
            }
        }
    }

    public function __destruct() {
        $this->close();
    }

        public function sendMsg(string $performative, string $sender, string $receiver, string $content): void {
        $msg = json_encode(['type' => 'message', 'performative' => $performative, 'sender' => $sender, 'receiver' => $receiver, 'content' => $content]) . "\n";
        fwrite($this->socket, $msg);
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
        $depthBrackets = 0;
        $depthParens = 0;
        for ($i = 0; $i < strlen($argsStr); $i++) {
            $char = $argsStr[$i];
            if ($char === '"') {
                $insideQuotes = !$insideQuotes;
                $current .= $char;
            } else if (!$insideQuotes && $char === '[') {
                $depthBrackets++;
                $current .= $char;
            } else if (!$insideQuotes && $char === ']') {
                $depthBrackets--;
                $current .= $char;
            } else if (!$insideQuotes && $char === '(') {
                $depthParens++;
                $current .= $char;
            } else if (!$insideQuotes && $char === ')') {
                $depthParens--;
                $current .= $char;
            } else if ($char === ',' && !$insideQuotes && $depthBrackets === 0 && $depthParens === 0) {
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
        $s = trim($arg);
        if (str_starts_with($s, '"') && str_ends_with($s, '"') && strlen($s) >= 2) {
            return substr($s, 1, -1);
        }
        return $s;
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
        if ($this->socket) {
            fclose($this->socket);
            $this->socket = null;
        }
        if ($this->process) {
            proc_terminate($this->process);
            $this->process = null;
        }
    }
}
