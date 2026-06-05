# frozen_string_literal: true

require_relative 'record_manager'

module RubyMysqlTui
  module InputHandler
    # RecordSortHandler は レコードのソート操作を提供します。
    module RecordSortHandler
      module_function

      def handle_sort_record(state, client, prompt)
        return state unless RecordManager.can_manage_record?(state)

        cols = client.list_columns(state[:selected_table])
        col = prompt.select('ソートするカラムを選択してください:', cols)
        return state if col.nil?

        dir = prompt.select('ソート方向を選択してください:', %w[ASC DESC])
        update_sort_state(state, client, col, dir)
      end

      def update_sort_state(state, client, col, dir)
        state.merge!(sort_column: col, sort_direction: dir, page_offset: 0, records_offset: 0)
        state[:records] = client.list_records(state[:selected_table], 0, sort_column: col, sort_direction: dir)
        state
      end
    end
  end
end
