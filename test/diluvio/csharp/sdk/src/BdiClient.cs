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

        private readonly System.Diagnostics.Process _process;

        private static int GetFreePort()
        {
            var listener = new TcpListener(System.Net.IPAddress.Loopback, 0);
            listener.Start();
            int port = ((System.Net.IPEndPoint)listener.LocalEndpoint).Port;
            listener.Stop();
            return port;
        }

        private static string FindBinary()
        {
            bool isWin = System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows);
            string binName = isWin ? "panteao-engine.exe" : "panteao-engine";
            
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            if (!string.IsNullOrEmpty(baseDir))
            {
                string cand1 = Path.Combine(baseDir, binName);
                if (File.Exists(cand1)) return cand1;
                string cand2 = Path.Combine(baseDir, "bin", binName);
                if (File.Exists(cand2)) return cand2;
            }
            
            string cwd = Directory.GetCurrentDirectory();
            string cand3 = Path.Combine(cwd, binName);
            if (File.Exists(cand3)) return cand3;
            string cand4 = Path.Combine(cwd, "bin", binName);
            if (File.Exists(cand4)) return cand4;
            
            return binName;
        }

        public BdiClient(string host, int port, string project = null)
        {
            if (string.IsNullOrEmpty(host))
            {
                host = "127.0.0.1";
            }
            if (!string.IsNullOrEmpty(project))
            {
                if (port == 0)
                {
                    port = GetFreePort();
                }
                string bin = FindBinary();
                _process = new System.Diagnostics.Process();
                _process.StartInfo.FileName = bin;
                _process.StartInfo.Arguments = $"\"{project}\" --port {port}";
                _process.StartInfo.UseShellExecute = false;
                _process.StartInfo.CreateNoWindow = true;
                _process.Start();
                Thread.Sleep(800);
            }
            else
            {
                _process = null;
                if (port == 0) port = 44444;
            }

            _client = new TcpClient(host, port);
            _stream = _client.GetStream();
            _writer = new StreamWriter(_stream, new UTF8Encoding(false)) { AutoFlush = true };
            _reader = new StreamReader(_stream, Encoding.UTF8);

            while (true)
            {
                string line = _reader.ReadLine();
                if (line == null) throw new IOException("Connection lost during handshake");
                if (line.Contains("\"type\":\"mas_ready\""))
                {
                    break;
                }
            }

            _handlers = new ConcurrentDictionary<string, Action<string[], Action<bool>>>();
            _running = true;

            _listenerThread = new Thread(Listen) { IsBackground = true };
            _listenerThread.Start();
        }

        public System.Threading.Tasks.Task ConnectAsync()
        {
            return System.Threading.Tasks.Task.CompletedTask;
        }

        public void SendMsg(string performative, string sender, string receiver, string content)
        {
            var payload = $"{{\"type\":\"message\",\"performative\":\"{performative}\",\"sender\":\"{sender}\",\"receiver\":\"{receiver}\",\"content\":\"{content}\"}}";
            lock (_writer)
            {
                _writer.WriteLine(payload);
            }
        }

        public void Close()
        {
            Dispose();
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
            int depthBrackets = 0;
            int depthParens = 0;
            foreach (char c in argsStr)
            {
                if (c == '"')
                {
                    insideQuotes = !insideQuotes;
                    current.Append(c);
                }
                else if (!insideQuotes && c == '[')
                {
                    depthBrackets++;
                    current.Append(c);
                }
                else if (!insideQuotes && c == ']')
                {
                    depthBrackets--;
                    current.Append(c);
                }
                else if (!insideQuotes && c == '(')
                {
                    depthParens++;
                    current.Append(c);
                }
                else if (!insideQuotes && c == ')')
                {
                    depthParens--;
                    current.Append(c);
                }
                else if (c == ',' && !insideQuotes && depthBrackets == 0 && depthParens == 0)
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
            string s = arg.Trim();
            if (s.StartsWith("\"") && s.EndsWith("\"") && s.Length >= 2)
            {
                return s.Substring(1, s.Length - 2);
            }
            return s;
        }

        public void Dispose()
        {
            _running = false;
            try { _reader.Dispose(); } catch {}
            try { _writer.Dispose(); } catch {}
            try { _stream.Dispose(); } catch {}
            try { _client.Dispose(); } catch {}
            try
            {
                if (_process != null && !_process.HasExited)
                {
                    _process.Kill();
                    _process.Dispose();
                }
            }
            catch {}
        }
    }
}
