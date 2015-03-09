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
  class Capture < ::Array
    # TODO: push each Run to the current Capture, then "jQuery" on the ary of Runs
  end

  class Run
    attr_reader :id, :status
    def initialize sh, id, status
      @sh = sh
      @id = id
      @status = status
    end
    def stdout
      
    end
  end

  def initialize args, &block
    @ssh_args = args
    
    @ssh_multiplexing = ['-S', "#{local_tmpdir}/ssh-%r@%h:%p"]
    
    # -M for master connection
    @in, @out, @err, @wait_thread = Open3.popen3(*ssh_command, '-M', 'bash -')
    # flush immediately
    @in.sync = true
    # Thread.new do
    #   @out.each_char { |char| print char }
    # end
    
    as_dsl block if block
  end

  def local_tmpdir
    @local_tmpdir ||= Dir.mktmpdir(self.class.name.gsub(/\W/,'-'), '/tmp/')
  end

  def as_dsl block
    instance_exec &block
    close
  end

  def capture
    @capture_stack ||= []
    @capture_stack.push Capture.new
    yield
    @capture_stack.pop
  end

  def next_run_id
    @run_id ||= 0
    @run_id += 1
  end
  def run cmd
    run_id = next_run_id
    prefix = "#{tmpdir}/run-#{run_id}"
    file_write "#{prefix}-cmd", cmd
    @in.write ". #{prefix}-cmd </dev/null >#{prefix}-out 2>#{prefix}-err; echo $?\n"
    status = @out.readline.chomp
    status = status == '' ? nil : status.to_i
    return Run.new(self, run_id, status)
  end

  def tmpdir
    @tmpdir ||= mktemp
  end

  def mktemp
    i, o, e, w = Open3.popen3(*ssh_command, "mktemp -d")
    i.close
    e.close
    name = o.read.chomp
    status = w.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to mktemp with status '#{status}'" unless status == 0
    name
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
  def read_file_read path
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
    FileUtils.remove_entry local_tmpdir
  end
  
  def ssh_command
    # http://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing
    ['ssh', *@ssh_multiplexing, *@ssh_args]
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
