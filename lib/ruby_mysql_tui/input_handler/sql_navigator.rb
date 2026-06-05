# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # SqlNavigator は SQL 履歴のナビゲーション（上下移動）を管理します。
    module SqlNavigator
      module_function

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
end
