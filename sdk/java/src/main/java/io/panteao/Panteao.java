package io.panteao;

public class Panteao extends BdiClient {
    public Panteao(String host) throws Exception {
        super(host);
    }
    public Panteao(String host, int port) throws Exception {
        super(host, port);
    }
    public Panteao(String host, int port, String project) throws Exception {
        super(host, port, project);
    }
    public Panteao(String host, int port, String project, boolean dev) throws Exception {
        super(host, port, project, dev);
    }
}
