require 'socket'
require 'json'

host = '127.0.0.1'
port = 44444
start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

puts '[DILUVIO] Ruby client starting'
begin
  socket = TCPSocket.new(host, port)
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000
  puts "[DILUVIO] Connected in #{elapsed.round(2)}ms"

  sleep 1

  percept = "{\"type\":\"perception\",\"action\":\"add\",\"perception\":\"transport_needed(ponto_a)\"}\n"
  puts "[DILUVIO] Sending: #{percept.strip}"
  socket.puts(percept)

  while line = socket.gets
    puts "[DILUVIO] Received: #{line.strip}"
    if line.include?('"type":"action"')
      msg = JSON.parse(line)
      id = msg['id']
      response = "{\"type\":\"action_result\",\"id\":\"#{id}\",\"success\":true}\n"
      puts "[DILUVIO] Sending result: #{response.strip}"
      socket.puts(response)
      puts '[DILUVIO] SUCCESS'
      break
    end
  end
  socket.close
rescue => e
  puts "[DILUVIO] FAILURE: #{e.message}"
  exit(1)
end
