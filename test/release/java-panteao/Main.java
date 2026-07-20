import br.com.kkphoenix.jason.ipc.sdk.Panteao;
public class Main {
    public static void main(String[] args) throws Exception {
        Panteao engine = new Panteao("./project.jcm");
        engine.connect();
    }
}
