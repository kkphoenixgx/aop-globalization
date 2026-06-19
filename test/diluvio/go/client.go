// ============================================================================
// Operação Dilúvio — A Tempestade IoT (Go / Golang)
//
// Go simulates 100 IoT water-level sensors using goroutines.
// Uses the high-level panteao.BdiClient callback API.
// ============================================================================

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// ---------------------------------------------------------------------------
// High-Level BdiClient SDK Implementation (embedded for self-contained Docker context)
// ---------------------------------------------------------------------------

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
	return strings.Trim(strings.TrimSpace(arg), `\"`)
}

func (c *BdiClient) Close() error {
	c.mu.Lock()
	c.running = false
	c.mu.Unlock()
	return c.conn.Close()
}

// ---------------------------------------------------------------------------
// Test Constants & Main Logic
// ---------------------------------------------------------------------------

const (
	host           = "127.0.0.1"
	port           = 44444
	numSensors     = 100
	criticalSensor = 42
	criticalLevel  = 95
	startupDelay   = 1 * time.Second
	timeout        = 5 * time.Second
)

func main() {
	tStart := time.Now()
	fmt.Println("[DILUVIO] A Tempestade IoT — Go/Golang test starting")
	fmt.Printf("[DILUVIO] Simulating %d IoT water-level sensors (%d readings each)\n", numSensors, 3)

	fmt.Printf("[DILUVIO] Waiting %v for engine readiness...\n", startupDelay)
	time.Sleep(startupDelay)

	tConnect := time.Now()
	addr := fmt.Sprintf("%s:%d", host, port)
	client, err := Connect(addr)
	if err != nil {
		fmt.Printf("[DILUVIO] FAIL: connection error: %v\n", err)
		return
	}
	defer client.Close()

	connectMs := float64(time.Since(tConnect).Microseconds()) / 1000.0
	fmt.Printf("[DILUVIO] Connected to engine at %s (%.2fms)\n", addr, connectMs)

	actionChan := make(chan bool, 1)
	tAction := time.Now()

	client.RegisterAction("update_dashboard", func(args []string, respond func(success bool)) {
		actionMs := float64(time.Since(tAction).Microseconds()) / 1000.0
		fmt.Printf("[DILUVIO] Action received: update_dashboard(%v) (%.2fms)\n", args, actionMs)
		respond(true)
		actionChan <- true
	})

	tPerceptions := time.Now()
	var sentCount int64
	var wg sync.WaitGroup

	for i := 0; i < numSensors; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			levels := [3]int{
				10 + (id % 30),
				40 + (id % 25),
				50 + (id % 40),
			}
			if id == criticalSensor {
				levels = [3]int{30, 65, criticalLevel}
			}
			for _, level := range levels {
				percept := fmt.Sprintf("water_level(s_%d,%d)", id, level)
				if err := client.SendPerception("add", percept); err != nil {
					fmt.Printf("[DILUVIO] Sensor s_%d send error: %v\n", id, err)
					return
				}
				atomic.AddInt64(&sentCount, 1)
			}
		}(i)
	}

	wg.Wait()
	perceptionMs := float64(time.Since(tPerceptions).Microseconds()) / 1000.0
	totalSent := atomic.LoadInt64(&sentCount)
	fmt.Printf("[DILUVIO] Sent %d perceptions from %d sensors (%.2fms)\n", totalSent, numSensors, perceptionMs)

	select {
	case <-actionChan:
		totalMs := float64(time.Since(tStart).Microseconds()) / 1000.0
		fmt.Println()
		fmt.Println("[DILUVIO] === Timing Metrics ===")
		fmt.Printf("[DILUVIO]   Connection     : %.2fms\n", connectMs)
		fmt.Printf("[DILUVIO]   Perceptions    : %.2fms\n", perceptionMs)
		fmt.Printf("[DILUVIO]   Total elapsed  : %.2fms\n", totalMs)
		fmt.Println("[DILUVIO] =======================")
		fmt.Println("[DILUVIO] SUCCESS")
	case <-time.After(timeout):
		fmt.Println("[DILUVIO] FAILURE — no action received from engine")
	}
}
