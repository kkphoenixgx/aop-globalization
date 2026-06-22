package panteao

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

type ActionCallback func(args []string, respond func(success bool))

type Config struct {
	Host    string
	Port    int
	Project string
	BinPath string
}

type BdiClient struct {
	conn     net.Conn
	cmd      *exec.Cmd
	handlers map[string]ActionCallback
	mu       sync.Mutex
	running  bool
}

type PerceptionMessage struct {
	Type       string `json:"type"`
	Action     string `json:"action"`
	Perception string `json:"perception"`
}

type ActionRequest struct {
	Type   string `json:"type"`
	ID     string `json:"id"`
	Agent  string `json:"agent"`
	Action string `json:"action"`
}

type ActionResult struct {
	Type    string `json:"type"`
	ID      string `json:"id"`
	Success bool   `json:"success"`
}

type SpeechActMessage struct {
	Type         string `json:"type"`
	Performative string `json:"performative"`
	Sender       string `json:"sender"`
	Receiver     string `json:"receiver"`
	Content      string `json:"content"`
}

func getFreePort() (int, error) {
	addr, err := net.ResolveTCPAddr("tcp", "localhost:0")
	if err != nil {
		return 0, err
	}
	l, err := net.ListenTCP("tcp", addr)
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func StartAndConnect(cfg Config) (*BdiClient, error) {
	var cmd *exec.Cmd
	host := cfg.Host
	if host == "" {
		host = "127.0.0.1"
	}
	port := cfg.Port

	if cfg.Project != "" {
		if port == 0 {
			var err error
			port, err = getFreePort()
			if err != nil {
				return nil, err
			}
		}

		binPath := "panteao-engine"
		execPath, err := os.Executable()
		if err == nil {
			execDir := filepath.Dir(execPath)
			binName := "panteao-engine"
			if runtime.GOOS == "windows" {
				binName = "panteao-engine.exe"
			}
			candidate1 := filepath.Join(execDir, binName)
			candidate2 := filepath.Join(execDir, "bin", binName)
			if _, err := os.Stat(candidate1); err == nil {
				binPath = candidate1
			} else if _, err := os.Stat(candidate2); err == nil {
				binPath = candidate2
			}
		}

		cmd = exec.Command(binPath, cfg.Project, "--port", strconv.Itoa(port))
		if err := cmd.Start(); err != nil {
			return nil, fmt.Errorf("failed to start GraalVM engine process: %v", err)
		}
		// Wait brief moment for the engine to initialize
		time.Sleep(800 * time.Millisecond)
	} else if port == 0 {
		port = 44444
	}

	addr := net.JoinHostPort(host, strconv.Itoa(port))
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		if cmd != nil {
			cmd.Process.Kill()
		}
		return nil, err
	}
	reader := bufio.NewReader(conn)
	
	// Wait for mas_ready handshake before returning
	for {
		line, err := reader.ReadBytes('\n')
		if err != nil {
			conn.Close()
			if cmd != nil {
				cmd.Process.Kill()
			}
			return nil, err
		}
		var msg map[string]interface{}
		if err := json.Unmarshal(line, &msg); err == nil {
			if msg["type"] == "mas_ready" {
				break
			}
		}
	}

	client := &BdiClient{
		conn:     conn,
		cmd:      cmd,
		handlers: make(map[string]ActionCallback),
		running:  true,
	}
	go client.listen(reader)
	return client, nil
}

func Connect(addr string) (*BdiClient, error) {
	host, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		host = "127.0.0.1"
		portStr = addr
	}
	port, _ := strconv.Atoi(portStr)
	return StartAndConnect(Config{
		Host: host,
		Port: port,
	})
}

func (c *BdiClient) SendMsg(performative, sender, receiver, content string) error {
	msg := SpeechActMessage{
		Type:         "message",
		Performative: performative,
		Sender:       sender,
		Receiver:     receiver,
		Content:      content,
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	_, err = c.conn.Write(append(data, '\n'))
	return err
}

func (c *BdiClient) SendPerception(action, perception string) error {
	msg := PerceptionMessage{
		Type:       "perception",
		Action:     action,
		Perception: perception,
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	_, err = c.conn.Write(append(data, '\n'))
	return err
}

func (c *BdiClient) RegisterAction(actionName string, callback ActionCallback) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.handlers[actionName] = callback
}

func (c *BdiClient) sendActionResult(id string, success bool) {
	msg := ActionResult{
		Type:    "action_result",
		ID:      id,
		Success: success,
	}
	data, _ := json.Marshal(msg)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.conn.Write(append(data, '\n'))
}

func (c *BdiClient) listen(reader *bufio.Reader) {
	for {
		c.mu.Lock()
		active := c.running
		c.mu.Unlock()
		if !active {
			break
		}
		line, err := reader.ReadBytes('\n')
		if err != nil {
			break
		}
		var req ActionRequest
		if err := json.Unmarshal(line, &req); err == nil && req.Type == "action" {
			name, args := parseAction(req.Action)
			c.mu.Lock()
			handler, ok := c.handlers[name]
			c.mu.Unlock()
			if ok {
				handler(args, func(success bool) {
					c.sendActionResult(req.ID, success)
				})
			} else {
				c.sendActionResult(req.ID, true)
			}
		}
	}
}

func parseAction(actionStr string) (string, []string) {
	parenIdx := strings.Index(actionStr, "(")
	if parenIdx == -1 {
		return strings.TrimSpace(actionStr), []string{}
	}
	name := strings.TrimSpace(actionStr[:parenIdx])
	argsStr := actionStr[parenIdx+1 : strings.LastIndex(actionStr, ")")]
	
	var args []string
	var current strings.Builder
	insideQuotes := false
	depthBrackets := 0
	depthParens := 0
	for _, char := range argsStr {
		if char == '"' {
			insideQuotes = !insideQuotes
			current.WriteRune(char)
		} else if !insideQuotes && char == '[' {
			depthBrackets++
			current.WriteRune(char)
		} else if !insideQuotes && char == ']' {
			depthBrackets--
			current.WriteRune(char)
		} else if !insideQuotes && char == '(' {
			depthParens++
			current.WriteRune(char)
		} else if !insideQuotes && char == ')' {
			depthParens--
			current.WriteRune(char)
		} else if char == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0 {
			args = append(args, cleanArg(current.String()))
			current.Reset()
		} else {
			current.WriteRune(char)
		}
	}
	if current.Len() > 0 {
		args = append(args, cleanArg(current.String()))
	}
	return name, args
}

func cleanArg(arg string) string {
	s := strings.TrimSpace(arg)
	if strings.HasPrefix(s, `"`) && strings.HasSuffix(s, `"`) && len(s) >= 2 {
		return s[1 : len(s)-1]
	}
	return s
}

func (c *BdiClient) Close() error {
	c.mu.Lock()
	c.running = false
	cmd := c.cmd
	c.mu.Unlock()
	
	if cmd != nil && cmd.Process != nil {
		cmd.Process.Kill()
	}
	return c.conn.Close()
}
