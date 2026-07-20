import br.com.kkphoenix.jason.ipc.sdk.Panteao
object Main extends App {
  val engine = new Panteao("./project.jcm")
  engine.connect()
}
