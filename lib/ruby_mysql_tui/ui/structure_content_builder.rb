# frozen_string_literal: true

require 'tty-table'

module RubyMysqlTui
  module UI
    # StructureContentBuilder は テーブル構造のレンダリングロジックを提供します。
    module StructureContentBuilder
      module_function

      def build_view(state, width, height)
        build_text(
          table_name: state[:selected_table],
          structure: state[:records],
          width: width,
          options: {
            height: height,
            offset: state[:records_offset] || 0,
            columns_offset: state[:columns_offset] || 0
          }
        )
      end

      def build_text(table_name:, structure:, width:, options: {})
        height = options[:height]
        offset = options[:offset] || 0
        columns_offset = options[:columns_offset] || 0
        header = ContentBuilder.truncate("Table Structure: #{table_name}", width)
        if structure.nil? || structure.none?
          return "#{header}\n\n#{ContentBuilder.truncate('No structure information found', width)}"
        end

        max_rows = height ? [0, height - 4].max : nil
        table_output = create_table(structure, width, max_rows, offset, columns_offset).to_s
        "#{header}\n\n#{table_output}"
      end

      def create_table(structure, width, max_rows = nil, offset = 0, columns_offset = 0)
        columns = structure.first.keys
        visible_columns = columns.drop(columns_offset)
        display_structure = structure.drop(offset).take(max_rows || structure.size)
        col_width = ContentBuilder.calculate_col_width(width, visible_columns.size)

        TTY::Table.new(
          header: visible_columns.map { |c| ContentBuilder.truncate(c, col_width) },
          rows: format_structure_rows(display_structure, columns_offset, col_width)
        )
      end

      private_class_method def format_structure_rows(structure, columns_offset, col_width)
        structure.map do |row|
          row.values.drop(columns_offset).map do |v|
            ContentBuilder.truncate(v.to_s, col_width)
          end
        end
      end
    end
  end
end
