# frozen_string_literal: true

require 'tty-table'

module RubyMysqlTui
  module UI
    # RecordsContentBuilder は レコード表示のレンダリングロジックを提供します。
    module RecordsContentBuilder
      module_function

      def build_view(state, width, height)
        records = state[:records] || []
        selected_index = calculate_selected_index(state, records.size)

        build_records_text(
          table_name: state[:selected_table],
          records: records,
          width: width,
          options: view_options(state, height).merge(selected_index: selected_index)
        )
      end

      def calculate_selected_index(state, records_size)
        index = state[:selected_record_index] || 0
        index.clamp(0, [0, records_size - 1].max)
      end
      private_class_method :calculate_selected_index

      def view_options(state, height)
        {
          height: height, selected_index: state[:selected_record_index],
          offset: state[:records_offset] || 0, columns_offset: state[:columns_offset] || 0,
          sort_column: state[:sort_column], sort_direction: state[:sort_direction],
          sql_result_mode: state[:sql_result_mode], last_executed_sql: state[:last_executed_sql],
          total_records: state[:total_records], records_size: (state[:records] || []).size
        }.compact
      end

      def build_records_text(table_name:, records:, width:, options: {})
        header = build_header(table_name, width, options)
        return "#{header}\n\n#{ContentBuilder.truncate('No records found', width)}" if records.nil? || records.none?

        max_rows = options[:height] ? [0, options[:height] - 4].max : nil
        table_output = create_records_table(records, width, max_rows, options).to_s
        "#{header}\n\n#{table_output}"
      end

      def build_header(table_name, width, options)
        sort_info = options[:sort_column] ? " (Sorted by #{options[:sort_column]} #{options[:sort_direction]})" : ''
        count_info = build_count_info(options)
        text = if options[:sql_result_mode]
                 "SQL Result: #{options[:last_executed_sql]}#{sort_info}"
               else
                 "Table: #{table_name}#{count_info}#{sort_info}"
               end
        ContentBuilder.truncate(text, width)
      end
      private_class_method :build_header

      def build_count_info(options)
        total = options[:total_records]
        return '' if total.nil?

        offset = options[:offset] || 0
        records_size = options[:records_size] || 0
        return "(0 of 0)" if total.zero?

        start_num = offset + 1
        end_num = offset + records_size
        "(#{start_num}-#{end_num} of #{total})"
      end
      private_class_method :build_count_info

      def create_records_table(records, width, max_rows, options = {})
        columns = records.first.keys
        return TTY::Table.new(rows: [['No columns available']]) if columns.empty?

        prepare_table_data(records, width, max_rows, options)
      end

      def prepare_table_data(records, width, max_rows, options)
        actual_offset = ContentBuilder.calculate_actual_offset(records, options[:columns_offset])
        visible_columns = records.first.keys.drop(actual_offset)
        col_width = ContentBuilder.calculate_col_width(width, visible_columns.size)
        display_records = slice_records(records, max_rows, options[:offset] || 0)

        TTY::Table.new(
          header: ContentBuilder.format_header(visible_columns, col_width),
          rows: format_records_rows(display_records, col_width, options[:selected_index], actual_offset)
        )
      end
      private_class_method :prepare_table_data

      def slice_records(records, max_rows, offset = 0)
        records.drop(offset).take(max_rows || records.size)
      end
      private_class_method :slice_records

      def format_records_rows(records, col_width, selected_index = nil, actual_offset = 0)
        records.map.with_index do |row, idx|
          format_record_row(row, col_width, idx == selected_index, actual_offset)
        end
      end
      private_class_method :format_records_rows

      def format_record_row(row, col_width, is_selected, actual_offset)
        row.values.drop(actual_offset).map.with_index do |val, col_idx|
          val_str = val.nil? ? 'NULL' : val.to_s
          text = ContentBuilder.truncate(val_str, col_width)
          is_selected && col_idx.zero? ? "> #{text}" : text
        end
      end
      private_class_method :format_record_row
    end
  end
end
