require 'jimson'

PORT = 9292
HOST = 'localhost'

c = Jimson::Client.new("http://localhost:9292/")
p c.start("rtmp://pcgw.pgw.jp/live/9001","rtmp://pcgw.pgw.jp/live/hoge")
p c.stats
