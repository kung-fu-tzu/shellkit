#!/usr/bin/env ruby

require 'tmpdir'
require 'open3'

# TODO: ssh user@host -M -S /tmp/%r@%h:%p -N

# TODO: sh.source("cat < #{file()}")
# TODO: Thread.new { pipe(:foo).write 'bla-bla' while true}; sh.source("ls | #{pipe(:foo)}")

# TODO: try again:
# NEWLINE_ERROR = %{newline character (\\n or \\r) has been found in the command passed; use source() for running multiline commands}
# raise NEWLINE_ERROR if /[\n\r]/.match(cmd)
# @in.write "read -rs #{@buffer_name}"
# @in.write "#{cmd}\n"

# TODO: set up timeouts


class RemoteShell
  class Capture
    def initialize sh, run_id
      @sh = sh
      @run_id = run_id
    end
    def stdout
      'sh.file_read'
    end
  end

  def initialize args, &block
    @ssh_args = args
    
    @tmpdir = Dir.mktmpdir(self.class.name.gsub(/\W/,'-'))
    p @tmpdir
    
    # -M for master connection
    @in, @out, @err, @wait_thread = Open3.popen3(*ssh_command, '-M', 'bash -')
    # flush immediately
    @in.sync = true
    # Thread.new do
    #   @out.each_char { |char| print char }
    # end
    @capture_stack = []
    @capture_n = 0
    as_dsl block if block
  end
  
  def as_dsl block
    instance_exec &block
    close
  end

  def capture
    @capture_stack.push Capture.new(self, @capture_n += 1)
    yield
    @capture_stack.pop
  end

  def remote_source_file_path
    '/tmp/remote_shell_source_file'
  end
  def run cmd
    file_write remote_source_file_path, cmd
    @in.write ". #{remote_source_file_path} </dev/null >/dev/null 2>&1; echo $?\n"
    @status = @out.readline.to_i
    return @status == 0
  end

  def file_write path, data
    i, o, e, w = Open3.popen3(*ssh_command, "cat >#{path}")
    o.close
    e.close
    i.write data
    i.close
    status = w.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to write file '#{path}' with status '#{status}'" unless status == 0
  end
  def file_read path
    io = IO.popen([*ssh_command, "cat #{path}"], 'r')
    data = io.read
    io.close
    return data
  end

  def close
    @in.close
    @out.close
    @err.close
    @wait_thread.value
    FileUtils.remove_entry @tmpdir
  end
  
  def ssh_command
    # http://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing
    multiplexing = %w{-S /tmp/%r@%h:%p}
    ['ssh', *multiplexing, *@ssh_args]
  end
end


# sh = RemoteShell.new 'default'
# p sh.run 'id'
# sh.close

RemoteShell.new 'default' do
  # h = capture { p run 'id' }
  # p h.stdout
  run 'ls / | cat > xxx.txt'
  p file_read 'xxx.txt'
end
