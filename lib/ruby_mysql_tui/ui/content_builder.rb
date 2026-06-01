# frozen_string_literal: true

module RubyMysqlTui
  module UI
    # ContentBuilder は TUI 画面に表示するためのテキスト構築ロジックを提供します。
    module ContentBuilder
      module_function

      def build_list_text(items, selected_index, width)
        return 'No items found' if items.nil? || items.empty?

        content_width = width - 2
        items.map.with_index do |item, idx|
          text = idx == selected_index ? "> #{item}" : "  #{item}"
          truncate(text, content_width)
        end.join("\n")
      end

      def build_right_text(state, width, height = nil)
        content_width = width - 2
        case state[:view_mode]
        when :databases then build_databases_text(content_width)
        when :tables then build_tables_text(state[:selected_db], state[:items], content_width)
        when :records then build_records_text(state[:selected_table], state[:records], content_width, height, state[:records_offset] || 0)
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

      def build_records_text(table_name, records, width, height = nil, offset = 0)
        header = truncate("Table: #{table_name}", width)
        return "#{header}\n\n#{truncate('No records found', width)}" if records.nil? || records.empty?

        # 表示可能行数の計算: ヘッダー(1) + 空行(1) + テーブルヘッダー(2) = 4行を差し引く
        max_rows = height ? [0, height - 4].max : nil
        table_output = create_records_table(records, width, max_rows, offset).to_s
        truncated_table = (table_output || '').lines.map { |line| truncate(line.chomp, width) }.join("\n")
        "#{header}\n\n#{truncated_table}"
      end

      def create_records_table(records, width, max_rows = nil, offset = 0)
        columns = records.first.keys
        return TTY::Table.new(rows: [['No columns available']]) if columns.empty?

        # 表示可能件数でスライス
        display_records = max_rows ? records[offset, max_rows] : records[offset..-1]
        display_records ||= []

        col_width = [(width - (columns.size * 3) - 1) / columns.size, 1].max

        TTY::Table.new(
          header: columns.map { |c| truncate(c, col_width) },
          rows: format_records_rows(display_records, col_width)
        )
      end

      def format_records_rows(records, col_width)
        records.map do |row|
          row.values.map { |val| truncate(val.to_s, col_width) }
        end
      end

      def truncate(text, width)
        return text if text.nil? || width <= 0
        return text[0...width] if width < 3

        text.length > width ? "#{text[0...(width - 3)]}..." : text
      end
    end
  end
end
