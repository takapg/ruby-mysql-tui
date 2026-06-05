# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # Pagination は レコードビューにおけるページネーション（オフセット管理とデータフェッチ）を提供します。
    module Pagination
      module_function

      def update_records_offset(state, delta, client, layout)
        state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, Float::INFINITY)
        fetch_page_if_needed(state, client, layout)
      end

      def fetch_page_if_needed(state, client, layout)
        return if state[:all_records_mode]

        offset = state[:records_offset]
        page_offset = state[:page_offset] || 0
        records = state[:records] || []
        main_h = layout.main_h

        if offset + main_h >= page_offset + records.size
          fetch_next_page(state, client, page_offset, records.size, state[:sort_column], state[:sort_direction])
        elsif offset < page_offset
          fetch_prev_page(state, client, state[:sort_column], state[:sort_direction])
        end
      end

      def fetch_next_page(state, client, page_offset, records_size, sort_col = nil, sort_dir = 'ASC')
        new_offset = page_offset + records_size
        records = client.list_records(
          state[:selected_table], new_offset, sort_column: sort_col, sort_direction: sort_dir
        ).to_a

        if records.empty?
          # 次ページが空の場合、ページオフセットは更新せず、
          # 現在のページの末尾にオフセットを固定して負の相対オフセットを防ぐ
          state[:records_offset] = [0, page_offset + records_size - 1].max
        else
          state[:page_offset] = new_offset
          state[:records] = records
        end
      end

      def fetch_prev_page(state, client, sort_col = nil, sort_dir = 'ASC')
        new_offset = [0, (state[:page_offset] || 0) - RubyMysqlTui::PAGE_SIZE].max
        state[:page_offset] = new_offset
        state[:records] = client.list_records(
          state[:selected_table], new_offset, sort_column: sort_col, sort_direction: sort_dir
        ).to_a
      end
    end
  end
end
