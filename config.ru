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
require 'shellwords'

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
    srcword = Shellwords.escape(src)
    dstword = Shellwords.escape(dst)
    pid = spawn("ffmpeg -loglevel -8 -i #{srcword} -vcodec copy -acodec copy -f flv #{dstword}")
    @mon.synchronize do
      @procs << { pid: pid, src: src, dst: dst, created_at: Time.now }
    end
    nil
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

  # 内部状態の定期的な更新。
  def update
    @mon.synchronize do
      begin
        # 終了したプロセスをプロセスリストから外す。
        pid = Process.waitpid(-1, Process::WNOHANG)
        if pid
          puts "pid #{pid} has died"
          @procs.delete_if do |pr|
            pr[:pid] == pid
          end
        else
          # 子プロセスが存在するが、終了したものはない場合。
        end
      rescue Errno::ECHILD
        # 起動直後など子プロセスがない場合、例外が上がる。
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
