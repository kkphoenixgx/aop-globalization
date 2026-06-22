require 'socket'
require 'json'

module Panteao
  class BdiClient
    def self.get_free_port
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      port
    end

    def self.find_binary
      is_win = Gem.win_platform?
      bin_name = is_win ? 'panteao-engine.exe' : 'panteao-engine'
      
      current_dir = File.expand_path(File.dirname(__FILE__))
      cand1 = File.join(current_dir, bin_name)
      return cand1 if File.exist?(cand1)
      cand2 = File.join(current_dir, 'bin', bin_name)
      return cand2 if File.exist?(cand2)
      
      cwd = Dir.pwd
      cand3 = File.join(cwd, bin_name)
      return cand3 if File.exist?(cand3)
      cand4 = File.join(cwd, 'bin', bin_name)
      return cand4 if File.exist?(cand4)
      
      bin_name
    end

    def initialize(host = '127.0.0.1', port = 0, project: nil)
      if project
        if port == 0
          port = self.class.get_free_port
        end
        bin = self.class.find_binary
        @pid = spawn(bin, project, '--port', port.to_s, out: File::NULL, err: File::NULL)
        sleep 0.8
      elsif port == 0
        port = 44444
      end

      @socket = TCPSocket.new(host, port)
      while (line = @socket.gets)
        break if line.include?('"type":"mas_ready"')
      end

      @handlers = {}
      @running = true
      @thread = Thread.new { listen }
    end

        def send_msg(performative, sender, receiver, content)
      msg = { type: 'message', performative: performative, sender: sender, receiver: receiver, content: content }
      @socket.puts(msg.to_json)
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
      depth_brackets = 0
      depth_parens = 0
      
      args_str.each_char do |c|
        if c == '"'
          inside_quotes = !inside_quotes
          current << c
        elsif !inside_quotes && c == '['
          depth_brackets += 1
          current << c
        elsif !inside_quotes && c == ']'
          depth_brackets -= 1
          current << c
        elsif !inside_quotes && c == '('
          depth_parens += 1
          current << c
        elsif !inside_quotes && c == ')'
          depth_parens -= 1
          current << c
        elsif c == ',' && !inside_quotes && depth_brackets == 0 && depth_parens == 0
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
      s = arg.strip
      if s.start_with?('"') && s.end_with?('"') && s.length >= 2
        return s[1..-2]
      end
      s
    end

    public

    def close
      @running = false
      @socket.close rescue nil
      @thread.join rescue nil
      if @pid
        Process.kill('KILL', @pid) rescue nil
        Process.wait(@pid) rescue nil
        @pid = nil
      end
    end
  end
end
