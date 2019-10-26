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
      @procs
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
      @procs.delete_if do |p|
        if p[:pid] == pid
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
        @procs.delete_if do |p|
          p[:pid] == pid
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
