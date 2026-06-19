using System;
using System.Net.Sockets;
using System.Text;
class Client {
    static void Main() {
        using TcpClient client = new TcpClient("127.0.0.1", 40000);
        using NetworkStream stream = client.GetStream();
        byte[] data = Encoding.UTF8.GetBytes("{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"test_percept\"}\n");
        stream.Write(data, 0, data.Length);
    }
}