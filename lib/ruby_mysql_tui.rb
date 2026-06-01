# frozen_string_literal: true

require 'logger'
require 'mysql2'
require_relative 'ruby_mysql_tui/client'
require 'tty-reader'
require_relative 'ruby_mysql_tui/ui/layout'
require_relative 'ruby_mysql_tui/ui/renderer'

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
    begin
      client = Client.new
      verify_connection(client)
      run_main_loop(client)
    rescue StandardError => e
      logger.error "Initialization failed: #{e.message}"
    ensure
      client&.close
    end
  end

  def self.verify_connection(client)
    client.query('SELECT 1')
    logger.info 'MySQL connection verified.'
  end

  def self.run_main_loop(client)
    reader = TTY::Reader.new
    layout = UI::Layout.new
    renderer = UI::Renderer.new(layout)

    loop do
      renderer.render(client)
      break if reader.read_char == 'q'
    end
  end
end
