require 'grape/middleware/base'
require_relative 'logger'

# adapted from:
# https://github.com/aserafin/grape_logging/blob/master/lib/grape_logging/middleware/request_logger.rb

module HighScore
  module Middleware
    class RequestLogger < Grape::Middleware::Base
      def call!(env)
        original_response = nil
        duration = Benchmark.realtime { original_response = super(env) }
        logger.info parameters(original_response, duration)
        original_response
      end

      protected
      def parameters(response, duration)
        {
          path: request.path,
          params: request.params,
          method: request.request_method,
          total: (duration * 1000).round(2),
          #db: request.env[:db_duration].round(2),
          status: response.first
        }
      end

      private
      def logger
        HighScore::Logger.logger('API')
      end

      def request
        @request ||= ::Rack::Request.new(env)
      end
    end
  end
end
