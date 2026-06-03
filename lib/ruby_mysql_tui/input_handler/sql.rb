# frozen_string_literal: true

module RubyMysqlTui
  # InputHandler の SQL モードに関する処理を定義します。
  module InputHandler
    module_function

    def execute_sql(sql, state, client)
      return state if sql.nil? || sql.strip.empty?

      results = begin
        client.query(sql)
      rescue StandardError => e
        [{ 'Error' => e.message }]
      end

      state.merge!(records: results, view_mode: :records, sql_mode: false)
      state
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
      else handle_sql_text_input(event, state)
      end
    end

    def handle_sql_text_input(event, state)
      if event.key.name == :backspace
        state[:sql_input] = state[:sql_input].chop
      elsif event.value && !event.value.start_with?("\e")
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
