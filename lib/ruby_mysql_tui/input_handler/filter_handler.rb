# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # FilterHandler は '/' キーによるフィルタ入力と 'Esc' キーによるフィルタクリアを処理します。
    module FilterHandler
      # The filter input methods are internal and should not be public.

      def handle_filter_input(val, state, client = nil)
        return clear_filter!(state, client) if val == "\e"
        return start_filter_input(state, client, TTY::Prompt.new) if val == '/'

        state
      end

      private def start_filter_input(state, client, prompt)
        filter = prompt.ask('フィルタ条件を入力してください:')

        if state[:focus] == :right
          apply_record_filter!(state, client, filter)
        else
          apply_item_filter!(state, filter)
        end

        state
      rescue TTY::Reader::InputInterrupt
        state
      end

      private def apply_record_filter!(state, client, filter)
        update_filter_state!(state, filter)
        fetch_filtered_records!(state, client)
        state
      end

      private def update_filter_state!(state, filter)
        state[:records_filter_query] = filter.to_s
        state[:records_offset] = 0
        state[:selected_record_index] = 0
      end

      private def fetch_filtered_records!(state, client)
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
        if state[:focus] == :right
          clear_right_filter(state, client)
        else
          state[:filter_query] = ''
          state[:selected_index] = 0
        end
        state
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
