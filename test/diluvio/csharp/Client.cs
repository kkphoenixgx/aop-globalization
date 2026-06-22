using System;
using System.Threading;
using System.Threading.Tasks;
using Panteao.Client;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("[DILUVIO] C# client starting");
        var client = new BdiClient("127.0.0.1", 44444);

        var cts = new CancellationTokenSource(5000);
        cts.Token.Register(() => {
            Console.WriteLine("[DILUVIO] TIMEOUT");
            client.Close();
            Environment.Exit(1);
        });

        bool actionHandled = false;
        client.RegisterAction("dispatch_military_support", (argsList, respond) => {
            Console.WriteLine("[DILUVIO] Action handled: dispatch_military_support");
            respond(true);
            Console.WriteLine("[DILUVIO] SUCCESS");
            actionHandled = true;
            client.Close();
            Environment.Exit(0);
        });

        try {
            client.ConnectAsync().Wait();
            Console.WriteLine("[DILUVIO] Connected!");
            client.SendMsg("tell", "external", "orquestrador", "military_request(-23.55,-46.63)");
            
            while (!actionHandled) {
                Thread.Sleep(100);
            }
        } catch (Exception e) {
            Console.WriteLine($"[DILUVIO] FAILURE: {e.Message}");
            Environment.Exit(1);
        }
    }
}
