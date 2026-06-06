# frozen_string_literal: true

require 'tty-table'

module RubyMysqlTui
  module UI
    # StructureContentBuilder は テーブル構造のレンダリングロジックを提供します。
    module StructureContentBuilder
      module_function

      def build_view(state, width, height)
        options = {
          height: height,
          offset: state[:records_offset] || 0,
          columns_offset: state[:columns_offset] || 0
        }
        build_text(
          table_name: state[:selected_table], structure: state[:records],
          width: width, selected_index: state[:selected_record_index], options: options
        )
      end

      def build_text(table_name:, structure:, width:, selected_index: nil, options: {})
        height = options[:height]
        header = ContentBuilder.truncate("Table Structure: #{table_name}", width)
        if structure.nil? || structure.none?
          return "#{header}\n\n#{ContentBuilder.truncate('No structure information found', width)}"
        end

        max_rows = height ? [0, height - 4].max : nil
        table_params = options.merge(max_rows: max_rows, selected_index: selected_index)
        table_output = create_table(structure, width, table_params).to_s
        "#{header}\n\n#{table_output}"
      end

      def create_table(structure, width, options = {})
        params = calculate_table_params(structure, width, options)

        TTY::Table.new(
          header: ContentBuilder.format_header(params[:columns], params[:col_width]),
          rows: format_structure_rows(
            params[:display_structure], params[:actual_offset], params[:col_width],
            options[:selected_index], options[:offset] || 0
          )
        )
      end

      private_class_method def calculate_table_params(structure, width, options)
        offset = options[:offset] || 0
        columns_offset = options[:columns_offset] || 0
        max_rows = options[:max_rows]

        actual_offset = ContentBuilder.calculate_actual_offset(structure, columns_offset)
        visible_columns = structure.first.keys.drop(actual_offset)
        col_width = ContentBuilder.calculate_col_width(width, visible_columns.size)
        display_structure = structure.drop(offset).take(max_rows || structure.size)

        {
          columns: visible_columns, col_width: col_width,
          display_structure: display_structure, actual_offset: actual_offset
        }
      end

      private_class_method def format_structure_rows(
        structure, actual_offset, col_width, selected_index = nil, offset = 0
      )
        structure.each_with_index.map do |row, idx|
          row.values.drop(actual_offset).map.with_index do |v, col_idx|
            text = ContentBuilder.truncate(v.to_s, col_width)
            col_idx.zero? && idx + offset == selected_index ? "> #{text}" : text
          end
        end
      end
    end
  end
end
