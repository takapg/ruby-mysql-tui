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
      state, should_break = handle_loop_input(reader, state, client)
      break if should_break
    end
  end

  def self.handle_loop_input(reader, state, client)
    return handle_sql_mode_input(reader, state, client) if state[:sql_mode]

    event = reader.read_keypress
    return [state, true] if event.value == 'q'

    [handle_input(event, state, client), false]
  end

  private_class_method def self.handle_sql_mode_input(reader, state, client)
    event = reader.read_keypress
    process_sql_keypress(event, state, client)
  end

  private_class_method def self.process_sql_keypress(event, state, client)
    case event.key.name
    when :escape
      [state.merge!(sql_mode: false, sql_input: ''), false]
    when :return
      handle_sql_return(state, client)
    when :backspace
      state[:sql_input] = state[:sql_input].chop
      [state, false]
    else
      state[:sql_input] += event.value if event.value
      [state, false]
    end
  end

  private_class_method def self.handle_sql_return(state, client)
    if state[:sql_input].strip == 'q' || state[:sql_input].strip.empty?
      return [state.merge!(sql_mode: false, sql_input: ''), false]
    end

    new_state = InputHandler.execute_sql(state[:sql_input], state, client)
    [new_state.merge!(sql_input: ''), false]
  end

  def self.initial_state(client)
    {
      focus: :left, selected_index: 0, view_mode: :databases,
      selected_db: nil, selected_table: nil, records: [],
      items: client.list_databases, sql_mode: false, sql_input: ''
    }
  end

  def self.handle_input(event, state, client)
    InputHandler.handle_input(event, state, client)
  end
end
