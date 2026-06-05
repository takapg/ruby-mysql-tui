# frozen_string_literal: true

require_relative 'sql_history_manager'

module RubyMysqlTui
  # InputHandler の SQL モードに関する処理を定義します。
  module InputHandler
    module_function

    def execute_sql(sql, state, client)
      return state if sql.nil? || sql.strip.empty?

      update_sql_history(sql, state)
      results = query_mysql(sql, client)

      state[:items] = refresh_items(state, client)

      state.merge!(
        records: results,
        view_mode: :records,
        sql_mode: false,
        sql_history_index: nil
      )
    end

    def refresh_items(state, client)
      if state[:selected_database]
        client.list_tables(state[:selected_database])
      else
        client.list_databases
      end
    end

    def update_sql_history(sql, state)
      return if sql.nil? || sql.strip.empty?

      history = state[:sql_history] || []
      return if history.last == sql

      history << sql
      SqlHistoryManager.save_history(history)
    end

    def query_mysql(sql, client)
      results = client.query(sql)
      return results if results

      affected = client.connection.affected_rows
      last_id = client.connection.last_id
      message = "Query OK, #{affected} rows affected"
      message += " (last id: #{last_id})" if last_id&.positive?
      [{ 'Result' => message }]
    rescue StandardError => e
      [{ 'Error' => e.message }]
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

    def handle_sql_history_up(state)
      history = state[:sql_history] || []
      return [state, false] if history.empty?

      state[:sql_temp_input] = state[:sql_input] if state[:sql_history_index].nil?

      index = calculate_up_index(state, history)
      state[:sql_input] = history[index]
      state[:sql_history_index] = index
      [state, false]
    end

    def calculate_up_index(state, history)
      index = state[:sql_history_index]
      if index.nil?
        history.size - 1
      else
        [0, index - 1].max
      end
    end

    def handle_sql_history_down(state)
      index = state[:sql_history_index]
      return [state, false] if index.nil?

      update_state_from_down_index(state, index + 1)
      [state, false]
    end

    def update_state_from_down_index(state, index)
      history = state[:sql_history] || []
      if index >= history.size
        state[:sql_input] = state[:sql_temp_input] || ''
        state[:sql_history_index] = nil
      else
        state[:sql_input] = history[index]
        state[:sql_history_index] = index
      end
    end
  end
end
