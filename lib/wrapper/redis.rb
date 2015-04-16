require 'init'

module HighScore
  module Wrapper
    def self.redis
      Redis.new({
       :host => Global.redis.host,
       :port => Global.redis.port,
       :db => Global.redis.db,
      })
    end
  end
end
