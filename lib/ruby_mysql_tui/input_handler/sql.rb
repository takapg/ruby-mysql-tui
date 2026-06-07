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

    public *SqlNavigator.methods(false)
    public *SqlEditor.methods(false)
    public *SqlExecutor.methods(false)

    module_function

    MAX_HISTORY_SIZE = 100

    def execute_sql(sql, state, client)
      return state if sql.nil? || sql.strip.empty?

      update_sql_history(sql, state)
      use_match = detect_use_statement(sql)
      state[:selected_db] = use_match[1] if use_match

      results = query_mysql(sql, client)
      state[:items] = refresh_items(state, client)

      use_match ? apply_use_state(state, sql) : apply_sql_result_state(state, results, sql)
    end

    def detect_use_statement(sql)
      sql.strip.match(/^\s*USE\s+`?([^`\s;]+)`?\s*;?\s*$/i)
    end

    def apply_use_state(state, sql)
      state.merge!(
        view_mode: :tables,
        sql_mode: false,
        sql_history_index: nil,
        sql_result_mode: false,
        last_executed_sql: sql
      )
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
      return [state.merge!(sql_mode: false, sql_input: ''), false] if event.value == 'q'

      case event.key.name
      when :escape then [state.merge!(sql_mode: false, sql_input: ''), false]
      when :return then handle_sql_return(state, client)
      when :up then handle_sql_history_up(state)
      when :down then handle_sql_history_down(state)
      when :ctrl_e then open_external_editor(state)
      else handle_sql_text_input(event, state)
      end
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
  end
end
