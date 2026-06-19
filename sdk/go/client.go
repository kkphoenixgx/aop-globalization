package panteao

import (
	"bufio"
	"encoding/json"
	"net"
	"strings"
	"sync"
)

type ActionCallback func(args []string, respond func(success bool))

type BdiClient struct {
	conn     net.Conn
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

func Connect(addr string) (*BdiClient, error) {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return nil, err
	}
	client := &BdiClient{
		conn:     conn,
		handlers: make(map[string]ActionCallback),
		running:  true,
	}
	go client.listen()
	return client, nil
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

func (c *BdiClient) listen() {
	reader := bufio.NewReader(c.conn)
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
	for _, char := range argsStr {
		if char == '"' {
			insideQuotes = !insideQuotes
		} else if char == ',' && !insideQuotes {
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
	return strings.Trim(strings.TrimSpace(arg), `"`)
}

func (c *BdiClient) Close() error {
	c.mu.Lock()
	c.running = false
	c.mu.Unlock()
	return c.conn.Close()
}
