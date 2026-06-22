require_relative 'sdk/lib/panteao_client'

puts "[DILUVIO] Ruby client starting"
client = Panteao::BdiClient.new('127.0.0.1', 44444)

Thread.new do
  sleep 5
  puts "[DILUVIO] TIMEOUT"
  client.close
  exit(1)
end

client.register_action("redirect_buses_to") do |args, respond|
  puts "[DILUVIO] Action handled: redirect_buses_to"
  respond.call(true)
  puts "[DILUVIO] SUCCESS"
  client.close
  exit(0)
end

begin
  puts "[DILUVIO] Connected!"
  client.send_msg("tell", "external", "orquestrador", "transport_needed(point4)")
  sleep
rescue => e
  puts "[DILUVIO] FAILURE: #{e.message}"
  exit(1)
end
