using System;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;

namespace Diluvio.CSharp;

class Client
{
    private const string Host = "127.0.0.1";
    private const int Port = 44444;
    private const string Perception = "military_request(-22.90,-43.17)";
    private const string ExpectedAction = "dispatch_military_support";
    private const int TimeoutMs = 5000;

    static int Main()
    {
        var stopwatch = Stopwatch.StartNew();
        Console.WriteLine("[DILUVIO] C# - O Protocolo da Defesa Civil");
        Console.WriteLine($"[DILUVIO] Connecting to {Host}:{Port}...");

        try
        {
            // Wait for engine readiness
            Thread.Sleep(1000);

            using var client = new TcpClient();
            client.ReceiveTimeout = TimeoutMs;
            client.SendTimeout = TimeoutMs;
            client.Connect(Host, Port);

            using var stream = client.GetStream();
            using var reader = new StreamReader(stream, new UTF8Encoding(false));
            using var writer = new StreamWriter(stream, new UTF8Encoding(false)) { AutoFlush = true };

            var connectTime = stopwatch.ElapsedMilliseconds;
            Console.WriteLine($"[DILUVIO] Connected in {connectTime}ms");

            // Send perception
            var perception = new JsonObject
            {
                ["type"] = "perception",
                ["action"] = "add",
                ["perception"] = Perception
            };
            var perceptionJson = perception.ToJsonString();
            writer.WriteLine(perceptionJson);
            Console.WriteLine($"[DILUVIO] Sent perception: {Perception}");

            var sendTime = stopwatch.ElapsedMilliseconds;

            // Read lines looking for action request
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                line = line.Trim();
                if (string.IsNullOrEmpty(line)) continue;

                Console.WriteLine($"[DILUVIO] Received: {line}");

                JsonNode? node;
                try
                {
                    node = JsonNode.Parse(line);
                }
                catch
                {
                    continue;
                }

                if (node == null) continue;

                var msgType = node["type"]?.GetValue<string>();
                if (msgType != "action") continue;

                var action = node["action"]?.GetValue<string>() ?? "";
                var id = node["id"]?.GetValue<string>() ?? "";
                var agent = node["agent"]?.GetValue<string>() ?? "";

                Console.WriteLine($"[DILUVIO] Action request: action={action}, id={id}, agent={agent}");

                if (!action.StartsWith(ExpectedAction))
                {
                    Console.WriteLine($"[DILUVIO] WARN: Unexpected action '{action}', expected '{ExpectedAction}'");
                    continue;
                }

                // Respond with action_result
                var result = new JsonObject
                {
                    ["type"] = "action_result",
                    ["id"] = id,
                    ["success"] = true
                };
                writer.WriteLine(result.ToJsonString());

                var totalTime = stopwatch.ElapsedMilliseconds;
                Console.WriteLine($"[DILUVIO] Action result sent for id={id}");
                Console.WriteLine();
                Console.WriteLine("=== Timing Metrics ===");
                Console.WriteLine($"  Connection:  {connectTime}ms");
                Console.WriteLine($"  Perception:  {sendTime - connectTime}ms");
                Console.WriteLine($"  Round-trip:  {totalTime - sendTime}ms");
                Console.WriteLine($"  Total:       {totalTime}ms");
                Console.WriteLine("======================");
                Console.WriteLine();
                Console.WriteLine("[DILUVIO] SUCCESS");
                return 0;
            }

            Console.WriteLine("[DILUVIO] FAIL: Connection closed without receiving expected action");
            return 1;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[DILUVIO] FAIL: {ex.GetType().Name}: {ex.Message}");
            return 1;
        }
    }
}
