# frozen_string_literal: true

require 'logger'

# RubyMysqlTui は、MySQL 用の TUI ツールを提供します。
module RubyMysqlTui
  # ロガーの設定
  @logger_mutex = Mutex.new

  def self.logger
    return @logger if @logger

    @logger_mutex.synchronize do
      # TODO: 標準出力で問題ないか検討
      @logger ||= Logger.new($stdout).tap do |log|
        level_name = ENV.fetch('LOG_LEVEL', 'DEBUG').upcase
        log.level = Logger.const_defined?(level_name) ? Logger.const_get(level_name) : Logger::DEBUG
        log.formatter = proc do |severity, datetime, _progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
        end
      end
    end
  end

  def self.start
    logger.info 'Starting RubyMysqlTui...'
    # TODO: 実装
  end
end
