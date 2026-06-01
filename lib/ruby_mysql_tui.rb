# frozen_string_literal: true

require 'logger'
require 'mysql2'
require_relative 'ruby_mysql_tui/client'
require 'tty-reader'
require_relative 'ruby_mysql_tui/ui/layout'
require_relative 'ruby_mysql_tui/ui/renderer'
require_relative 'ruby_mysql_tui/input_handler'

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
    renderer = UI::Renderer.new(UI::Layout.new)
    state = initial_state(client)

    loop do
      renderer.render(client, state)
      if state[:sql_mode]
        input = reader.read_line("")
        if input == 'q' || input.nil?
          state[:sql_mode] = false
        else
          state = InputHandler.execute_sql(input, state, client)
        end
      else
        event = reader.read_keypress
        break if event.value == 'q'

        state = handle_input(event, state, client)
      end
    end
  end

  def self.initial_state(client)
    {
      focus: :left,
      selected_index: 0,
      view_mode: :databases,
      selected_db: nil,
      selected_table: nil,
      records: [],
      items: client.list_databases,
      sql_mode: false
    }
  end

  def self.handle_input(event, state, client)
    InputHandler.handle_input(event, state, client)
  end
end
