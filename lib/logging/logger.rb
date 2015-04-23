require 'global'

module HighScore
  class Logger
    def self.logger(component = nil)
      log_file = Global.logging.path
      log_file = STDOUT if Global.logging.to_stdout
      logger = ::Logger.new(log_file)
      logger.level = ::Logger.const_get(Global.logging.level.upcase)

      logger.datetime_format = Global.logging.datetime_format ||

      if component
        logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{component}] #{severity}|#{datetime}: #{msg}\n"
        end
      else
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity}|#{datetime}: #{msg}\n"
        end
      end

      logger
    end
  end
end
