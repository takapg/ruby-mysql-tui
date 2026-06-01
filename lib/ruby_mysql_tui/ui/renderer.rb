# frozen_string_literal: true

require 'tty-box'
require 'tty-table'
require_relative 'layout'

module RubyMysqlTui
  module UI
    # Renderer は Layout に基づいて TUI 画面を描画します。
    class Renderer
      CLEAR_SCREEN = "\e[2J\e[H"

      def initialize(layout)
        @layout = layout
      end

      # 画面全体をレンダリングします。
      def render(client, state)
        @layout.update_dimensions
        print CLEAR_SCREEN

        render_header(client)
        render_main(state)
        render_log
        render_footer
      end

      private

      def render_header(client)
        text = "Host: #{client.config[:host]} | User: #{client.config[:username]} | DB: #{client.config[:database]}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.header_h) do
          text
        end
      end

      def render_main(state)
        left = build_box(@layout.left_w, build_list_text(state), state[:focus] == :left)
        right = build_box(
          @layout.right_w, build_right_text(state, @layout.right_w), state[:focus] == :right
        )

        render_side_by_side(left, right)
      end

      def build_list_text(state)
        items = state[:items]
        return 'No items found' if items.empty?

        content_width = @layout.left_w - 2
        items.each_with_index.map do |item, idx|
          text = idx == state[:selected_index] ? "> #{item}" : "  #{item}"
          truncate(text, content_width)
        end.join("\n")
      end

      def build_right_text(state, width)
        content_width = width - 2
        case state[:view_mode]
        when :databases then build_databases_text(content_width)
        when :tables then build_tables_text(state[:selected_db], state[:items], content_width)
        when :records then build_records_text(state[:selected_table], state[:records], content_width)
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

      def build_records_text(table_name, records, width)
        header = truncate("Table: #{table_name}", width)
        return "#{header}\n\n#{truncate('No records found', width)}" if records.nil? || records.empty?

        columns = records.first.keys
        col_width = (width / columns.size).floor - 1

        table = TTY::Table.new(
          header: columns.map { |c| truncate(c, col_width) },
          rows: format_records_rows(records, col_width)
        )
        "#{header}\n\n#{table.render}"
      end

      def format_records_rows(records, col_width)
        records.map do |row|
          row.values.map { |val| truncate(val.to_s, col_width) }
        end
      end

      def build_box(width, content, focused)
        TTY::Box.frame(
          width: width, height: @layout.main_h,
          style: { border: { fg: focused ? :cyan : :white } }
        ) { content }
      end

      def truncate(text, width)
        return text if text.nil? || width <= 0
        return text[0...width] if width < 3

        text.length > width ? "#{text[0...(width - 3)]}..." : text
      end

      def render_side_by_side(left_box, right_box)
        left_lines = left_box.split("\n", -1)
        right_lines = right_box.split("\n", -1)
        max_lines = [left_lines.length, right_lines.length].max

        (0...max_lines).each do |i|
          puts "#{left_lines[i]}#{right_lines[i]}"
        end
      end

      def render_log
        puts TTY::Box.frame(width: @layout.width, height: @layout.log_h) do
          'Last SQL: SELECT 1'
        end
      end

      def render_footer
        puts TTY::Box.frame(width: @layout.width, height: @layout.footer_h) do
          ' [q] Quit | [Tab] Switch Focus | [↑/↓] Move | [Enter] Select '
        end
      end
    end
  end
end
