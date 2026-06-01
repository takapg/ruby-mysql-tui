# frozen_string_literal: true

module RubyMysqlTui
  module UI
    # ContentBuilder は TUI 画面に表示するためのテキスト構築ロジックを提供します。
    module ContentBuilder
      def self.build_list_text(items, selected_index, width)
        return 'No items found' if items.nil? || items.empty?

        content_width = width - 2
        items.each_with_index.map do |item, idx|
          text = idx == selected_index ? "> #{item}" : "  #{item}"
          self.truncate(text, content_width)
        end.join("\n")
      end

      def self.build_right_text(state, width)
        content_width = width - 2
        case state[:view_mode]
        when :databases then self.build_databases_text(content_width)
        when :tables then self.build_tables_text(state[:selected_db], state[:items], content_width)
        when :records then self.build_records_text(state[:selected_table], state[:records], content_width)
        else self.truncate('Unknown view mode', content_width)
        end
      end

      def self.build_databases_text(width)
        self.truncate('Data will appear here', width)
      end

      def self.build_tables_text(selected_db, items, width)
        header = self.truncate("Database: #{selected_db}", width)
        if items.nil? || items.empty?
          "#{header}\n\n#{self.truncate('No tables found', width)}"
        else
          table_list = items.map { |item| self.truncate(item, width) }.join("\n")
          "#{header}\n\n#{table_list}"
        end
      end

      def self.build_records_text(table_name, records, width)
        header = self.truncate("Table: #{table_name}", width)
        return "#{header}\n\n#{self.truncate('No records found', width)}" if records.nil? || records.empty?

        table_output = self.create_records_table(records, width).render
        truncated_table = table_output.lines.map { |line| self.truncate(line.chomp, width) }.join("\n")
        "#{header}\n\n#{truncated_table}"
      end

      def self.create_records_table(records, width)
        columns = records.first.keys
        return TTY::Table.new(rows: [['No columns available']]) if columns.empty?

        col_width = [(width - (columns.size * 3) - 1) / columns.size, 1].max

        TTY::Table.new(
          header: columns.map { |c| self.truncate(c, col_width) },
          rows: self.format_records_rows(records, col_width)
        )
      end

      def self.format_records_rows(records, col_width)
        records.map do |row|
          row.values.map { |val| self.truncate(val.to_s, col_width) }
        end
      end

      def self.truncate(text, width)
        return text if text.nil? || width <= 0
        return text[0...width] if width < 3

        text.length > width ? "#{text[0...(width - 3)]}..." : text
      end
    end
  end
end
