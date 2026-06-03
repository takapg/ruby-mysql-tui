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
          options: { height: height }
        )
      end

      def build_text(table_name:, structure:, width:, options: {})
        height = options[:height]
        header = ContentBuilder.truncate("Table Structure: #{table_name}", width)
        return "#{header}\n\n#{ContentBuilder.truncate('No structure information found', width)}" if structure.nil? || structure.none?

        max_rows = height ? [0, height - 4].max : nil
        table_output = create_table(structure, width, max_rows).to_s
        "#{header}\n\n#{table_output}"
      end

      def create_table(structure, width, max_rows = nil)
        columns = structure.first.keys
        display_structure = structure.take(max_rows || structure.size)
        col_width = ContentBuilder.calculate_col_width(width, columns.size)

        TTY::Table.new(
          header: columns.map { |c| ContentBuilder.truncate(c, col_width) },
          rows: display_structure.map { |row| row.values.map { |v| ContentBuilder.truncate(v.to_s, col_width) } }
        )
      end
    end
  end
end
