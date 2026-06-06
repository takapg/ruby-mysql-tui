# frozen_string_literal: true

require 'tty-table'
require_relative 'structure_content_builder'
require_relative 'records_content_builder'

module RubyMysqlTui
  module UI
    # ContentBuilder は TUI 画面に表示するためのテキスト構築ロジックを提供します。
    module ContentBuilder
      module_function

      def self.filtered_items(state)
        items = state[:items] || []
        query = state[:filter_query]
        return items if query.nil? || query.empty?

        items.select { |item| item.downcase.include?(query.downcase) }
      end

      def build_list_text(items, selected_index, width, height = nil)
        return 'No items found' if items.nil? || items.empty?

        start_idx = calculate_start_index(items, selected_index, height)
        max_rows = height ? [0, height - 2].max : items.size

        render_visible_items(items, start_idx, max_rows, selected_index, width)
      end

      private_class_method def calculate_start_index(items, selected_index, height)
        return 0 unless height

        max_rows = [0, height - 2].max
        return 0 unless items.size > max_rows

        (selected_index - (max_rows / 2)).clamp(0, items.size - max_rows)
      end

      private_class_method def render_visible_items(items, start_idx, max_rows, selected_index, width)
        content_width = width - 2
        items[start_idx, max_rows].map.with_index do |item, idx|
          actual_idx = start_idx + idx
          text = actual_idx == selected_index ? "> #{item}" : "  #{item}"
          truncate(text, content_width)
        end.join("\n")
      end

      def build_right_text(state, width, height = nil)
        content_width = width - 2
        case state[:view_mode]
        when :databases then build_databases_text(content_width)
        when :tables then build_tables_text(state[:selected_db], state[:items], content_width)
        when :records then RecordsContentBuilder.build_view(state, content_width, height)
        when :record_detail then build_record_detail_text(state, content_width, height)
        when :table_structure then StructureContentBuilder.build_view(state, content_width, height)
        else truncate('Unknown view mode', content_width)
        end
      end

      def build_databases_text(width)
        truncate('Data will appear here', width)
      end

      def build_tables_text(selected_db, items, width)
        header = truncate("Database: #{selected_db}", width)
        if items.nil? || items.empty?
          "#{header}\n\n#{truncate('No tables found', width)}"
        else
          table_list = items.map { |item| truncate(item, width) }.join("\n")
          "#{header}\n\n#{table_list}"
        end
      end

      def build_record_detail_text(state, width, height)
        record = state[:records][state[:selected_record_index]]
        return truncate('No record selected', width) unless record

        rows = record.map { |k, v| "#{k}: #{v.nil? ? 'NULL' : v}" }
        offset = state[:detail_offset] || 0
        max_rows = height ? [0, height - 2].max : rows.size

        rows.drop(offset).take(max_rows).map do |row|
          truncate(row, width)
        end.join("\n")
      end

      def calculate_col_width(width, columns_count)
        return 0 if columns_count <= 0

        [(width - (columns_count * 3) - 1) / columns_count, 1].max
      end

      def calculate_actual_offset(records, offset)
        (offset || 0).clamp(0, [0, records.first&.keys&.size.to_i - 1].max)
      end

      def format_header(columns, col_width)
        columns.map { |c| truncate(c, col_width) }
      end

      def truncate(text, width)
        return text if text.nil? || width <= 0
        return text[0...width] if width < 3

        text.length > width ? "#{text[0...(width - 3)]}..." : text
      end
    end
  end
end
