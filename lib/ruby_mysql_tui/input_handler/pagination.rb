# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # Pagination は レコードビューにおけるページネーション（オフセット管理とデータフェッチ）を提供します。
    module Pagination
      module_function

      def update_records_offset(state, delta, client)
        state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, Float::INFINITY)
        fetch_page_if_needed(state, client)
      end

      def fetch_page_if_needed(state, client)
        offset = state[:records_offset]
        page_offset = state[:page_offset] || 0
        records = state[:records] || []

        if offset >= page_offset + records.size
          fetch_next_page(state, client, page_offset, records.size)
        elsif offset < page_offset
          fetch_prev_page(state, client)
        end
      end

      def fetch_next_page(state, client, page_offset, records_size)
        new_offset = page_offset + records_size
        state[:page_offset] = new_offset
        state[:records] = client.list_records(state[:selected_table], new_offset)
        state[:records_offset] = [0, page_offset + records_size - 1].max if state[:records].empty?
      end

      def fetch_prev_page(state, client)
        new_offset = [0, (state[:page_offset] || 0) - RubyMysqlTui::PAGE_SIZE].max
        state[:page_offset] = new_offset
        state[:records] = client.list_records(state[:selected_table], new_offset)
      end
    end
  end
end
