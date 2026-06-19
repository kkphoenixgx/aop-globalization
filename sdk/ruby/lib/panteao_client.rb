require 'socket'
require 'json'

module Panteao
  class BdiClient
    def initialize(host = '127.0.0.1', port = 44444)
      @socket = TCPSocket.new(host, port)
      @handlers = {}
      @running = true
      @thread = Thread.new { listen }
    end

    def send_perception(action, perception)
      payload = { type: 'perception', action: action, perception: perception }.to_json + "\n"
      @socket.write(payload)
    end

    def register_action(action_name, &block)
      @handlers[action_name] = block
    end

    private

    def send_action_result(id, success)
      payload = { type: 'action_result', id: id, success: success }.to_json + "\n"
      @socket.write(payload)
    end

    def listen
      while @running && (line = @socket.gets)
        handle_line(line.strip)
      end
    rescue => e
      # Connection lost
    end

    def handle_line(line)
      return if line.empty?
      begin
        msg = JSON.parse(line)
        if msg['type'] == 'action'
          raw_action = msg['action']
          action_id = msg['id']
          name, args = parse_action(raw_action)
          
          handler = @handlers[name]
          if handler
            respond = proc { |success| send_action_result(action_id, success) }
            handler.call(args, respond)
          else
            send_action_result(action_id, true)
          end
        end
      rescue => e
      end
    end

    def parse_action(action_str)
      paren_idx = action_str.index('(')
      return action_str.strip, [] unless paren_idx
      
      name = action_str[0...paren_idx].strip
      args_str = action_str[paren_idx + 1...action_str.rindex(')')]
      
      args = []
      current = ""
      inside_quotes = false
      
      args_str.each_char do |c|
        if c == '"'
          inside_quotes = !inside_quotes
        elsif c == ',' && !inside_quotes
          args << clean_arg(current)
          current = ""
        else
          current << c
        end
      end
      args << clean_arg(current) unless current.empty?
      
      return name, args
    end

    def clean_arg(arg)
      arg.strip.gsub(/^"|"$/, '')
    end

    public

    def close
      @running = false
      @socket.close rescue nil
      @thread.join rescue nil
    end
  end
end
