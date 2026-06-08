# frozen_string_literal: true

require_relative 'sql_history_manager'
require_relative 'sql_navigator'
require_relative 'sql_editor'
require_relative 'sql_executor'

module RubyMysqlTui
  # InputHandler の SQL モードに関する処理を定義します。
  module InputHandler
    extend SqlNavigator
    extend SqlEditor
    extend SqlExecutor

    MAX_HISTORY_SIZE = 100

    def execute_sql(sql, state, client)
      return state if sql.nil? || sql.strip.empty?

      update_sql_history(sql, state)
      results = query_mysql(sql, client)

      apply_execution_state(state, sql, results, detect_use_statement(sql))
      state[:items] = refresh_items(state, client)
      state
    end

    def refresh_items(state, client)
      if state[:selected_db]
        client.list_tables(state[:selected_db])
      else
        client.list_databases
      end
    rescue StandardError => e
      RubyMysqlTui.logger.error("Failed to refresh items: #{e.message}")
      state[:items]
    end

    def update_sql_history(sql, state)
      return if sql.nil? || sql.strip.empty?

      history = state[:sql_history] || []
      return if history.last == sql

      history.delete(sql)
      history << sql

      updated_history = history.last(MAX_HISTORY_SIZE)
      state[:sql_history] = updated_history
      SqlHistoryManager.save_history(updated_history)
    end

    def handle_sql_mode_input(reader, state, client)
      event = reader.read_keypress
      process_sql_keypress(event, state, client)
    end

    def process_sql_keypress(event, state, client)
      return handle_sql_quit(state) if event.value == 'q'

      dispatch_sql_keypress(event, state, client)
    end

    def dispatch_sql_keypress(event, state, client)
      case event.key.name
      when :escape then handle_sql_escape(state)
      when :return then handle_sql_return(state, client)
      when :up, :down then handle_sql_history_navigation(event, state)
      when :ctrl_e then open_external_editor(state)
      when :ctrl_k then handle_sql_history_clear(state)
      else handle_sql_text_input(event, state)
      end
    end

    def handle_sql_escape(state)
      [state.merge!(sql_mode: false, sql_input: ''), false]
    end

    def handle_sql_history_navigation(event, state)
      event.key.name == :up ? handle_sql_history_up(state) : handle_sql_history_down(state)
    end

    def handle_sql_quit(state)
      [state.merge!(sql_mode: false, sql_input: ''), false]
    end

    def handle_sql_text_input(event, state)
      if event.key.name == :backspace
        state[:sql_input] = state[:sql_input].chop
      elsif event.value.is_a?(String) && !event.value.start_with?("\e")
        state[:sql_input] += event.value
      end
      [state, false]
    end

    def handle_sql_return(state, client)
      return [state.merge!(sql_mode: false, sql_input: ''), false] if state[:sql_input].strip.empty?

      new_state = execute_sql(state[:sql_input], state, client)
      [new_state.merge!(sql_input: ''), false]
    end

    def handle_sql_history_clear(state)
      SqlHistoryManager.clear_history
      state[:sql_history] = []
      state[:sql_history_index] = nil
      [state, false]
    end

    module_function :execute_sql,
                    :refresh_items, :update_sql_history, :handle_sql_mode_input,
                    :process_sql_keypress, :dispatch_sql_keypress, :handle_sql_escape,
                    :handle_sql_history_navigation, :handle_sql_text_input, :handle_sql_return,
                    :handle_sql_history_clear, :handle_sql_quit
  end
end
