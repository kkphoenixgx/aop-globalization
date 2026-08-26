package io.panteao;

public class Panteao extends BdiClient {
    public Panteao(String host) {
        super(host);
    }
    public Panteao(String host, int port) {
        super(host, port);
    }
    public Panteao(String host, int port, String project) {
        super(host, port, project);
    }
    public Panteao(String host, int port, String project, boolean dev) {
        super(host, port, project, dev);
    }
}
