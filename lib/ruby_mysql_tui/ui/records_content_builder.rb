# frozen_string_literal: true

require 'tty-table'

module RubyMysqlTui
  module UI
    # RecordsContentBuilder は レコード表示のレンダリングロジックを提供します。
    module RecordsContentBuilder
      module_function

      def build_view(state, width, height)
        build_records_text(
          table_name: state[:selected_table],
          records: state[:records],
          width: width,
          options: view_options(state, height)
        )
      end

      def view_options(state, height)
        {
          height: height,
          selected_index: state[:selected_record_index],
          offset: state[:records_offset] || 0,
          columns_offset: state[:columns_offset] || 0
        }
      end

      def build_records_text(table_name:, records:, width:, options: {})
        height = options[:height]
        header = ContentBuilder.truncate("Table: #{table_name}", width)
        return "#{header}\n\n#{ContentBuilder.truncate('No records found', width)}" if records.nil? || records.none?

        max_rows = height ? [0, height - 4].max : nil
        table_output = create_records_table(records, width, max_rows, options).to_s
        "#{header}\n\n#{table_output}"
      end

      def create_records_table(records, width, max_rows, options = {})
        columns = records.first.keys
        return TTY::Table.new(rows: [['No columns available']]) if columns.empty?

        prepare_table_data(records, width, max_rows, options)
      end

      private_class_method def prepare_table_data(records, width, max_rows, options)
        columns_offset = options[:columns_offset] || 0
        actual_offset = columns_offset.clamp(0, [0, records.first.keys.size - 1].max)
        visible_columns = records.first.keys.drop(actual_offset)
        display_records = slice_records(records, max_rows, options[:offset] || 0)
        col_width = ContentBuilder.calculate_col_width(width, visible_columns.size)

        TTY::Table.new(
          header: visible_columns.map { |c| ContentBuilder.truncate(c, col_width) },
          rows: format_records_rows(display_records, col_width, options[:selected_index], actual_offset)
        )
      end

      private_class_method def slice_records(records, max_rows, offset = 0)
        records.drop(offset).take(max_rows || records.size)
      end

      private_class_method def format_records_rows(records, col_width, selected_index = nil, columns_offset = 0)
        columns_count = records.first&.keys&.size || 0
        actual_offset = columns_offset.clamp(0, [0, columns_count - 1].max)

        records.map.with_index do |row, idx|
          row.values.drop(actual_offset).map.with_index do |val, col_idx|
            text = ContentBuilder.truncate(val.to_s, col_width)
            idx == selected_index && col_idx.zero? ? "> #{text}" : text
          end
        end
      end
    end
  end
end
