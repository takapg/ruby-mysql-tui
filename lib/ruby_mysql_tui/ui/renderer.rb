# frozen_string_literal: true

require 'tty-box'
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
        render_main(state[:focus], state[:items], state[:selected_index], state[:view_mode], state[:selected_db])
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

      def render_main(focus, items, selected_index, view_mode, selected_db)
        left = build_box(@layout.left_w, build_list_text(items, selected_index), focus == :left)
        right = build_box(
          @layout.right_w, build_right_text(view_mode, selected_db, items, @layout.right_w), focus == :right
        )

        render_side_by_side(left, right)
      end

      def build_list_text(items, selected_index)
        return 'No items found' if items.empty?

        content_width = @layout.left_w - 2
        items.each_with_index.map do |item, idx|
          text = idx == selected_index ? "> #{item}" : "  #{item}"
          truncate(text, content_width)
        end.join("\n")
      end

      def build_right_text(view_mode, selected_db, items, width)
        content_width = width - 2
        case view_mode
        when :databases then build_databases_text(content_width)
        when :tables then build_tables_text(selected_db, items, content_width)
        else truncate('Unknown view mode', content_width)
        end
      end

      def build_databases_text(width)
        truncate('Data will appear here', width)
      end

      def build_tables_text(selected_db, items, width)
        header = truncate("Database: #{selected_db}", width)
        if items.empty?
          "#{header}\n\n#{truncate('No tables found', width)}"
        else
          table_list = items.map { |item| truncate(item, width) }.join("\n")
          "#{header}\n\n#{table_list}"
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

        text.length > width ? "#{text[0...(width - 3)]}..." : text
      end

      def render_side_by_side(left_box, right_box)
        left_lines = left_box.split("\n")
        right_lines = right_box.split("\n")

        max_lines = [left_lines.size, right_lines.size].max
        max_lines.times do |i|
          left = left_lines[i] || ''
          right = right_lines[i] || ''
          puts "#{left} #{right}"
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
