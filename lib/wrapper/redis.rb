require_relative '../logging/logger'

module HighScore
  module Wrapper
    def self.redis
      Redis.new({
       :host => Global.redis.host,
       :port => Global.redis.port,
       :db => Global.redis.db,
       :logger => HighScore::Logger.logger('Redis')
      })
    end
  end
end
