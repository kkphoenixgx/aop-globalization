// ============================================================================
// Operação Dilúvio — A Tempestade IoT (Go / Golang)
// ============================================================================

package main

import (
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	panteao "github.com/kkphoenixgx/panteao/sdk/go"
)

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
	client, err := panteao.Connect(addr)
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
				if err := client.SendMsg("tell", "external", "orquestrador", percept); err != nil {
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
