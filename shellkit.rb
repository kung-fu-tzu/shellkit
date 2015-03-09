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

# TODO: try subclass IO: RemoteShell < IO

class RemoteShell
  class Capture < ::Array
    # TODO: push each Run to the current Capture, then "jQuery" on the ary of Runs
  end

  class Run
    @@id = 0
    attr_reader :cmd, :status
    def initialize sh, cmd
      @sh = sh
      @cmd = cmd
    end
    def run
      return unless @sh
      @sh.file_write "#{prefix}-cmd", @cmd
      @sh.write ". #{prefix}-cmd </dev/null >#{prefix}-out 2>#{prefix}-err; echo $?\n"
      status = @sh.readline.chomp
      @status = status == '' ? nil : status.to_i
      @sh = nil # ensure single run
      self
    end
    def stdout
      @sh.file_read("#{@prefix}-out")
    end
    def stderr
      @sh.file_read("#{@prefix}-err")
    end
  private
    def prefix
      @prefix ||= "#{@sh.tmpdir}/run-#{@sh.next_id}"
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

  def write data
    @in.write data
  end
  def readline
    @out.readline
  end
  def run cmd
    Run.new(self, cmd).run
  end

  def tmpdir
    @tmpdir ||= mktemp
  end
  def next_id
    # store all the uniq data in one place - shell
    @id ||= 0
    @id += 1
  end

  def mktemp
    read_cmd("mktemp -d").chomp
  end
  def file_read path
    read_cmd("cat #{path}")
  end
  def file_write path, data
    write_cmd("cat >#{path}", data)
  end

  def read_cmd cmd
    i, o, e, w = Open3.popen3(*ssh_command, cmd)
    i.close
    e.close
    data = o.read
    o.close
    status = w.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to read command '#{cmd}' with status '#{status}'" unless status == 0
    data
  end
  def write_cmd cmd, data
    i, o, e, w = Open3.popen3(*ssh_command, cmd)
    o.close
    e.close
    i.write data
    i.close
    status = w.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to write to command '#{cmd}' with status '#{status}'" unless status == 0
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
