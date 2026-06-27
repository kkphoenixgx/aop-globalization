using System;
using Panteao.Sdk;

class Program
{
    static void Main()
    {
        Console.WriteLine("Iniciando Panteao no C#...");
        
        using var engine = new Panteao.Sdk.Panteao("127.0.0.1", 0, "./project.jcm");
        
        Console.WriteLine("teste log da minha aplicação C#");
        
        engine.Wait();
    }
}
