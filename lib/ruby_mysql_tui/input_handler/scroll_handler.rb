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
        return state unless state[:focus] == :right && state[:records]

        total_cols = state[:records].first&.keys&.size || 0
        state[:columns_offset] = ((state[:columns_offset] || 0) + delta).clamp(0, [0, total_cols - 1].max)
        state
      end

      def handle_scroll(state, client, delta)
        if state[:focus] == :left
          handle_left_scroll(state, delta)
        elsif state[:focus] == :right
          handle_right_scroll(state, client, delta)
        end
        state
      end

      def update_selected_index(state, delta)
        state[:selected_index] = (state[:selected_index] + delta).clamp(0, state[:items].size - 1)
      end

      def current_layout
        @current_layout ||= RubyMysqlTui::UI::Layout.new
        @current_layout.update_dimensions
        @current_layout
      end

      private_class_method def handle_left_scroll(state, delta)
        update_selected_index(state, delta) unless state[:items].empty?
      end

      private_class_method def handle_right_scroll(state, client, delta)
        return unless state[:records]

        case state[:view_mode]
        when :records then scroll_records(state, client, delta)
        when :table_structure then scroll_structure(state, delta)
        when :record_detail then scroll_detail(state, delta)
        end
        state
      end

      private_class_method def scroll_records(state, client, delta)
        Pagination.update_records_offset(state, delta, client, current_layout)
      end

      private_class_method def scroll_structure(state, delta)
        state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, state[:records].size)
      end

      private_class_method def scroll_detail(state, delta)
        record = state[:records][state[:selected_record_index]]
        return unless record

        state[:records_offset] = ((state[:records_offset] || 0) + delta).clamp(0, record.keys.size)
      end
    end
  end
end
