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
    renderer = UI::Renderer.new(UI::Layout.new)
    state = initial_state(client)

    loop do
      renderer.render(client, state)
      event = reader.read_keypress
      break if event.value == 'q'

      state = handle_input(event, state, client)
    end
  end

  def self.initial_state(client)
    {
      focus: :left,
      selected_index: 0,
      view_mode: :databases,
      selected_db: nil,
      items: client.list_databases
    }
  end

  def self.handle_input(event, state, client)
    case event.key.name
    when :tab then handle_tab(state)
    when :up then handle_up(state)
    when :down then handle_down(state)
    when :return then handle_return(state, client)
    else state
    end
  end

  def self.handle_tab(state)
    state[:focus] = (state[:focus] == :left ? :right : :left)
    state
  end

  def self.handle_up(state)
    state[:selected_index] = [0, state[:selected_index] - 1].max if state[:focus] == :left
    state
  end

  def self.handle_down(state)
    state[:selected_index] = [state[:items].size - 1, state[:selected_index] + 1].min if state[:focus] == :left
    state
  end

  def self.handle_return(state, client)
    if state[:focus] == :left && state[:view_mode] == :databases
      db_name = state[:items][state[:selected_index]]
      state[:selected_db] = db_name
      state[:view_mode] = :tables
      state[:items] = client.list_tables(db_name)
      state[:selected_index] = 0
    end
    state
  end
end
