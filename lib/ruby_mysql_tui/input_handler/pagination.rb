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
        return if state[:all_records_mode] || state[:sql_result_mode]

        if needs_next_page?(state, layout)
          fetch_next_page(state, client, page_offset: state[:page_offset] || 0, size: (state[:records] || []).size)
        elsif needs_prev_page?(state)
          fetch_prev_page(state, client)
        end
      end

      def needs_next_page?(state, layout)
        offset = state[:records_offset]
        page_offset = state[:page_offset] || 0
        records_size = (state[:records] || []).size
        offset + layout.main_h >= page_offset + records_size
      end

      def needs_prev_page?(state)
        (state[:records_offset] || 0) < (state[:page_offset] || 0)
      end

      def fetch_next_page(state, client, page_offset:, size:)
        new_offset = page_offset + size
        records = client.list_records(state[:selected_table], new_offset, **InputHandler.query_options(state)).to_a

        if records.empty?
          state[:records_offset] = [0, new_offset - 1].max
        else
          state[:page_offset] = new_offset
          state[:records] = records
        end
        state[:total_records] = client.count_records(
          state[:selected_table], filter_query: state[:records_filter_query]
        ) if state[:selected_table]
      end

      def fetch_prev_page(state, client)
        new_offset = [0, (state[:page_offset] || 0) - RubyMysqlTui::PAGE_SIZE].max
        state[:page_offset] = new_offset
        opts = InputHandler.query_options(state)
        state[:records] = client.list_records(state[:selected_table], new_offset, **opts).to_a
        state[:total_records] = client.count_records(
          state[:selected_table], filter_query: state[:records_filter_query]
        ) if state[:selected_table]
      end
    end
  end
end
