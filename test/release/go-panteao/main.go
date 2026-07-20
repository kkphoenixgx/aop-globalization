package main
import "github.com/kkphoenixgx/panteao/sdk/go"
func main() {
	engine := panteao.StartAndConnect(panteao.Config{ Project: "./project.jcm" })
	engine.Connect()
	select {}
}