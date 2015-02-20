#!/usr/bin/env ruby

require 'open3'

# ssh user@host -M -S /tmp/%r@%h:%p -N

Open3.popen3('ssh', 'ru', 'bash -') do |i,o,e,t|
  Thread.new do
    o.each_char {|char| print char }
  end
  i.write "id\n"
  i.write "ls -al\n"
  
  i.write "exit\n"
  
  t.value
end

# io = Process.spawn()
# 
# Thread.new do
#   io.each_char {|char| print char }
# end
# 
# Thread.new do
#   loop { io.write("id\n") }
# end
# 
# 
