import io.panteao.BdiClient

object Client {
  def main(args: Array[String]): Unit = {
    println("[DILUVIO] Scala client starting")
    val client = new BdiClient("127.0.0.1", 44444)

    val t = new Thread(() => {
      Thread.sleep(5000)
      println("[DILUVIO] TIMEOUT")
      client.close()
      System.exit(1)
    })
    t.start()

    client.registerAction("evacuate_zone", (actionArgs, respond) => {
      println("[DILUVIO] Action handled: otimizar_rotas")
      respond(true)
      println("[DILUVIO] SUCCESS")
      client.close()
      System.exit(0)
    })

    try {

      println("[DILUVIO] Connected!")
      client.sendMsg("tell", "external", "orquestrador", "soil_saturation_critical(zone3)")
      
      Thread.sleep(Long.MaxValue)
    } catch {
      case e: Exception =>
        println(s"[DILUVIO] FAILURE: ${e.getMessage}")
        System.exit(1)
    }
  }
}
