# frozen_string_literal: true

require_relative 'pagination'
require_relative '../ui/layout'

module RubyMysqlTui
  module InputHandler
    # ScrollHandler は 画面内のスクロール操作（上下移動、カラム移動）を管理します。
    module ScrollHandler
      module_function

      def handle_up(state, client)
        handle_scroll(state, client, -1)
      end

      def handle_down(state, client)
        handle_scroll(state, client, 1)
      end

      def handle_column_scroll(state, delta)
        return state unless can_scroll_columns?(state)

        total_cols = state[:records].first&.keys&.size || 0
        state[:columns_offset] = ((state[:columns_offset] || 0) + delta).clamp(0, [0, total_cols - 1].max)
        state
      end

      def handle_scroll(state, client, delta)
        if state[:focus] == :left
          state = handle_left_scroll(state, delta)
        elsif state[:focus] == :right
          state = handle_right_scroll(state, client, delta)
        end
        state
      end

      def update_selected_index(state, delta)
        items = RubyMysqlTui::UI::ContentBuilder.filtered_items(state)
        return if items.empty?

        state[:selected_index] = (state[:selected_index] + delta).clamp(0, items.size - 1)
      end

      def current_layout
        @current_layout ||= RubyMysqlTui::UI::Layout.new
        @current_layout.update_dimensions
        @current_layout
      end

      private_class_method def handle_left_scroll(state, delta)
        update_selected_index(state, delta)
        state
      end

      private_class_method def handle_right_scroll(state, client, delta)
        return state unless state[:records]

        case state[:view_mode]
        when :records
          state = scroll_records(state, client, delta)
        when :table_structure then state = scroll_structure(state, delta)
        when :record_detail then state = scroll_detail(state, delta)
        end
        state
      end

      private_class_method def scroll_records(state, client, delta)
        Pagination.update_records_offset(state, delta, client, current_layout)
        state
      end

      private_class_method def scroll_structure(state, delta)
        items = state[:records] || []
        return state if items.empty?

        new_idx = (state[:selected_record_index] || 0) + delta
        state[:selected_record_index] = new_idx.clamp(0, items.size - 1)

        layout = current_layout
        max_rows = [0, layout.main_h - 4].max
        offset = state[:records_offset] || 0
        idx = state[:selected_record_index]

        if idx < offset
          state[:records_offset] = idx
        elsif idx >= offset + max_rows
          state[:records_offset] = idx - max_rows + 1
        end
        state
      end

      private_class_method def scroll_detail(state, delta)
        record = state[:records][state[:selected_record_index]]
        return state unless record

        idx = (state[:selected_column_index] || 0) + delta
        state[:selected_column_index] = idx.clamp(0, [0, record.keys.size - 1].max)
        adjust_detail_offset(state)
        state
      end

      private_class_method def adjust_detail_offset(state)
        layout = current_layout
        max_rows = [0, layout.main_h - 2].max
        offset = state[:detail_offset] || 0
        idx = state[:selected_column_index]

        if idx < offset
          state[:detail_offset] = idx
        elsif idx >= offset + max_rows
          state[:detail_offset] = idx - max_rows + 1
        end
      end

      private_class_method def can_scroll_columns?(state)
        state[:focus] == :right && state[:records] && state[:view_mode] != :record_detail
      end
    end
  end
end
