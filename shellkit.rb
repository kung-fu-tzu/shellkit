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
      run
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
    def run
      # the actual magic
      @sh.file_write "#{prefix}-cmd", @cmd
      @sh.write ". #{prefix}-cmd </dev/null >#{prefix}-out 2>#{prefix}-err; echo $?\n"
      status = @sh.readline.chomp
      @status = status == '' ? nil : status.to_i
    end
    # delegate to stdout string
    alias :to_s :stdout
  end

  def initialize opts, &block
    @ssh_opts = opts
    
    # -M for master connection
    @master = ssh('-M', 'bash -')
    
    as_dsl block if block
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

  def tmpdir
    @tmpdir ||= read_cmd("mktemp -d").chomp
  end
  def next_id
    # store all the uniq data in one place - shell
    @id ||= 0
    @id += 1
  end

  def run cmd
    Run.new(self, cmd)
  end

  def write data
    @master.in.write data
  end
  def readline
    @master.out.readline
  end

  def file_read path
    read_cmd("cat #{path}")
  end
  def file_write path, data
    write_cmd("cat >#{path}", data)
  end

  def read_cmd cmd
    p = ssh(cmd)
    p.in.close
    p.err.close
    data = p.out.read
    p.out.close
    status = p.wait.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to read command '#{cmd}' with status '#{status}'" unless status == 0
    data
  end
  def write_cmd cmd, data
    p = ssh(cmd)
    p.out.close
    p.err.close
    p.in.write data
    p.in.close
    status = p.wait.value.exitstatus
    raise "failed to open ssh connection" if status == 255
    raise "failed to write to command '#{cmd}' with status '#{status}'" unless status == 0
  end

  Process = Struct.new(:in, :out, :err, :wait)
  def ssh *cmd
    # http://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing
    multiplexing = ['-S', "#{local_tmpdir}/ssh-%r@%h:%p"]
    p = Process.new *Open3.popen3('ssh', *multiplexing, *@ssh_opts, *cmd)
    # flush immediately
    p.in.sync = true
    p
  end

  def close
    FileUtils.remove_entry local_tmpdir
    @master.in.close
    @master.out.close
    @master.err.close
    @master.wait.value
  end

  def local_tmpdir
    @local_tmpdir ||= Dir.mktmpdir(self.class.name.gsub(/\W/,'-'), '/tmp/')
  end
end


# sh = RemoteShell.new 'default'
# p sh.run 'id'
# sh.close

RemoteShell.new 'default' do
  # h = capture { p run 'id' }
  # p h.stdout
  puts run('ls / | grep m').to_s
  # p file_read 'xxx.txt'
end
