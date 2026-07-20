using System;
using Panteão = Panteao.Sdk.Panteao;

class Program {
    static void Main() {
        using var engine = new Panteão(project: "./project.jcm");
        engine.Wait();
    }
}