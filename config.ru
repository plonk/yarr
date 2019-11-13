=begin

    Yarr - Yet another RTMP relayer
    Copyright (C) 2019 Yoteichi

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.

=end

require 'jimson'
require 'monitor'

class Handler
  extend Jimson::Handler

  def initialize(*args)
    @mon = Monitor.new
    @procs = []
  end

  def stats
    @mon.synchronize do
      @procs.dup
    end
  end

  def start(src, dst)
    @mon.synchronize do
      pid = spawn("ffmpeg -loglevel -8 -i #{src} -vcodec copy -acodec copy -f flv #{dst}")
      @procs << { pid: pid, src: src, dst: dst, created_at: Time.now }
    end
  rescue => e
    p e
    raise
  end

  def kill(pid)
    @mon.synchronize do
      success = false
      @procs.delete_if do |pr|
        if pr[:pid] == pid
          Process.kill("TERM", pid)
          success = true
          true
        else
          false
        end
      end
      success
    end
  end

  def sum(a,b) a+b end

  def update
    @mon.synchronize do
      begin
        pid = Process.waitpid(-1, Process::WNOHANG)
        puts "pid #{pid} has died"
        @procs.delete_if do |pr|
          pr[:pid] == pid
        end
      rescue Errno::ECHILD
      end
    end
  end

end

use Rack::Reloader, 0
use Rack::Runtime

handler = Handler.new
Thread.new do
  while true
    sleep 1
    handler.update
  end
end
run Jimson::Server.new(handler)
