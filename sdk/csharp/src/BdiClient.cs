using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Collections.Concurrent;
using System.Threading;
using System.Text.Json;
using System.Collections.Generic;

namespace Panteao.Client
{
    public class BdiClient : IDisposable
    {
        private readonly TcpClient _client;
        private readonly NetworkStream _stream;
        private readonly StreamWriter _writer;
        private readonly StreamReader _reader;
        private readonly ConcurrentDictionary<string, Action<string[], Action<bool>>> _handlers;
        private readonly Thread _listenerThread;
        private bool _running;

        public BdiClient(string host, int port)
        {
            _client = new TcpClient(host, port);
            _stream = _client.GetStream();
            _writer = new StreamWriter(_stream, new UTF8Encoding(false)) { AutoFlush = true };
            _reader = new StreamReader(_stream, Encoding.UTF8);
            _handlers = new ConcurrentDictionary<string, Action<string[], Action<bool>>>();
            _running = true;

            _listenerThread = new Thread(Listen) { IsBackground = true };
            _listenerThread.Start();
        }

        public void SendPerception(string action, string perception)
        {
            var payload = $"{{\"type\":\"perception\",\"action\":\"{action}\",\"perception\":\"{perception}\"}}";
            lock (_writer)
            {
                _writer.WriteLine(payload);
            }
        }

        public void RegisterAction(string actionName, Action<string[], Action<bool>> callback)
        {
            _handlers[actionName] = callback;
        }

        private void SendActionResult(string id, bool success)
        {
            var payload = $"{{\"type\":\"action_result\",\"id\":\"{id}\",\"success\":{(success ? "true" : "false")}}}";
            lock (_writer)
            {
                _writer.WriteLine(payload);
            }
        }

        private void Listen()
        {
            try
            {
                while (_running)
                {
                    string line = _reader.ReadLine();
                    if (line == null) break;
                    HandleLine(line.Trim());
                }
            }
            catch { }
        }

        private void HandleLine(string line)
        {
            if (string.IsNullOrEmpty(line)) return;
            try
            {
                using var doc = JsonDocument.Parse(line);
                var root = doc.RootElement;
                if (root.TryGetProperty("type", out var typeProp) && typeProp.GetString() == "action")
                {
                    string id = root.GetProperty("id").GetString();
                    string rawAction = root.GetProperty("action").GetString();
                    var (name, args) = ParseAction(rawAction);

                    if (_handlers.TryGetValue(name, out var handler))
                    {
                        handler(args, (success) => SendActionResult(id, success));
                    }
                    else
                    {
                        SendActionResult(id, true);
                    }
                }
            }
            catch { }
        }

        private (string, string[]) ParseAction(string actionStr)
        {
            int parenIdx = actionStr.IndexOf('(');
            if (parenIdx == -1)
            {
                return (actionStr.Trim(), Array.Empty<string>());
            }
            string name = actionStr.Substring(0, parenIdx).Trim();
            string argsStr = actionStr.Substring(parenIdx + 1, actionStr.LastIndexOf(')') - parenIdx - 1);
            
            var args = new List<string>();
            var current = new StringBuilder();
            bool insideQuotes = false;
            foreach (char c in argsStr)
            {
                if (c == '"')
                {
                    insideQuotes = !insideQuotes;
                }
                else if (c == ',' && !insideQuotes)
                {
                    args.Add(CleanArg(current.ToString()));
                    current.Clear();
                }
                else
                {
                    current.Append(c);
                }
            }
            if (current.Length > 0)
            {
                args.Add(CleanArg(current.ToString()));
            }
            return (name, args.ToArray());
        }

        private string CleanArg(string arg)
        {
            return arg.Trim().Trim('"');
        }

        public void Dispose()
        {
            _running = false;
            _reader.Dispose();
            _writer.Dispose();
            _stream.Dispose();
            _client.Dispose();
        }
    }
}
