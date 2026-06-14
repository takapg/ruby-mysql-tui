# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # FilterHandler は '/' キーによるフィルタ入力と 'Esc' キーによるフィルタクリアを処理します。
    module FilterHandler
      # The filter input methods are internal and should not be public.

      module_function

      def handle_filter_input(val, state, client = nil)
        return clear_filter!(state, client) if val == "\e"
        return start_filter_input(state, client, TTY::Prompt.new) if val == '/'

        state
      end

      def start_filter_input(state, client, prompt)
        # state を直接変更せず、コピーしたハッシュで操作して安全性を確保
        new_state = state.dup
        filter = prompt.ask('フィルタ条件を入力してください:')

        if new_state[:focus] == :right
          apply_record_filter!(new_state, client, filter)
        else
          apply_item_filter!(new_state, filter)
        end

        new_state
      rescue TTY::Reader::InputInterrupt
        # 入力が中断された場合は元の state をそのまま返す
        state
      end

      def apply_record_filter!(state, client, filter)
        update_filter_state!(state, filter)
        fetch_filtered_records!(state, client)
        state
      end

      def update_filter_state!(state, filter)
        state[:records_filter_query] = filter.to_s
        state[:records_offset] = 0
        state[:selected_record_index] = 0
      end

      def fetch_filtered_records!(state, client)
        return unless state[:selected_table] && client

        state[:records] = client.list_records(
          state[:selected_table], 0, InputHandler.query_options(state)
        )
        state[:total_records] = client.count_records(
          state[:selected_table], filter_query: state[:records_filter_query]
        )
      end

      def apply_item_filter!(state, filter)
        state[:filter_query] = filter.to_s
        state[:selected_index] = 0
      end

      def clear_filter!(state, client = nil)
        # state を直接変更せず、コピーしたハッシュで操作
        new_state = state.dup
        if new_state[:focus] == :right
          clear_right_filter(new_state, client)
        else
          new_state[:filter_query] = ''
          new_state[:selected_index] = 0
        end
        new_state
      end

      def clear_right_filter(state, client)
        state[:records_filter_query] = ''
        state[:records_offset] = 0
        state[:selected_record_index] = 0
        state[:total_records] = client.count_records(state[:selected_table]) if state[:selected_table] && client
        state
      end
    end
  end
end
