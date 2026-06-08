# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # FilterHandler は '/' キーによるフィルタ入力と 'Esc' キーによるフィルタクリアを処理します。
    module FilterHandler
      module_function

      def handle_filter_input(val, state, client = nil)
        return clear_filter(state) if val == "\e"

        start_filter_input(state, client)
      end

      private_class_method def start_filter_input(state, client)
        prompt = TTY::Prompt.new
        filter = prompt.ask('フィルタ条件を入力してください:')

        if state[:focus] == :right
          state[:records_filter_query] = filter.to_s
          state[:records_offset] = 0
          state[:selected_record_index] = 0

          if state[:selected_table] && client
            state[:records] = client.list_records(
              state[:selected_table],
              state[:records_offset],
              InputHandler.query_options(state)
            )
          end
        else
          state[:filter_query] = filter.to_s
          state[:selected_index] = 0
        end

        state
      rescue TTY::Reader::InputInterrupt
        state
      end

      private_class_method def clear_filter(state)
        if state[:focus] == :right
          state[:records_filter_query] = ''
          state[:records_offset] = 0
          state[:selected_record_index] = 0
        else
          state[:filter_query] = ''
          state[:selected_index] = 0
        end
        state
      end
    end
  end
end
