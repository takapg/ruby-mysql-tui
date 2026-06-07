# frozen_string_literal: true

require 'logger'
require 'mysql2'
require 'tty-prompt'
require_relative 'ruby_mysql_tui/client'
require 'tty-reader'
require_relative 'ruby_mysql_tui/ui/layout'
require_relative 'ruby_mysql_tui/ui/renderer'
require_relative 'ruby_mysql_tui/input_handler/sql_history_manager'
require_relative 'ruby_mysql_tui/input_handler'

# RubyMysqlTui は、MySQL 用の TUI ツールを提供します。
module RubyMysqlTui
  PAGE_SIZE = 100

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
      client = establish_connection
      return unless client

      run_main_loop(client)
    rescue Interrupt
      logger.info 'Interrupted by user. Exiting...'
    rescue StandardError => e
      logger.error "Initialization failed: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    ensure
      client&.close
    end
  end

  def self.verify_connection(client)
    client.query('SELECT 1')
    logger.info 'MySQL connection verified.'
  end

  def self.establish_connection
    config = nil
    loop do
      client, error = try_connect(config)
      return client if client

      config = handle_connection_failure(error)
      return nil unless config
    end
  end

  def self.try_connect(config)
    client = Client.new(config || {})
    verify_connection(client)
    [client, nil]
  rescue Mysql2::Error => e
    [nil, e]
  end

  def self.handle_connection_failure(error)
    logger.error "Connection failed: #{error.message}"
    prompt = TTY::Prompt.new
    return nil unless prompt.yes?('接続に失敗しました。接続情報を再入力しますか？')

    prompt_config(prompt)
  end

  def self.prompt_config(prompt)
    {
      host: prompt.ask('Host:', default: 'localhost'),
      username: prompt.ask('Username:', default: 'root'),
      password: prompt.mask('Password:'),
      database: prompt.ask('Database (optional):')
    }
  end

  def self.run_main_loop(client)
    reader = TTY::Reader.new
    renderer = UI::Renderer.new(UI::Layout.new)

    begin
      execute_main_loop(reader, renderer, client)
    rescue StandardError => e
      logger.error "Runtime error in main loop: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end
  end

  def self.execute_main_loop(reader, renderer, client)
    state = initial_state(client)
    loop do
      renderer.render(client, state)
      state, should_break = handle_loop_input(reader, state, client)
      break if should_break
    end
  end

  def self.handle_loop_input(reader, state, client)
    return InputHandler.handle_sql_mode_input(reader, state, client) if state[:sql_mode]

    event = reader.read_keypress
    val = event.respond_to?(:value) ? event.value : event
    return [state, true] if val == 'q'

    [handle_input(event, state, client), false]
  end

  def self.initial_state(client)
    {
      focus: :left, selected_index: 0, view_mode: :databases,
      selected_db: nil, selected_table: nil, records: [],
      items: client.list_databases, sql_mode: false, sql_input: '',
      records_offset: 0, page_offset: 0, all_records_mode: false,
      columns_offset: 0, sql_history: InputHandler::SqlHistoryManager.load_history,
      sql_history_index: nil, sql_temp_input: '', filter_query: '', records_filter_query: '', show_help: false
    }
  end

  def self.handle_input(event, state, client)
    InputHandler.handle_input(event, state, client)
  end
end
