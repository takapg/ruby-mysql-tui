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
      def render(client)
        @layout.update_dimensions
        print CLEAR_SCREEN

        render_header(client)
        render_main
        render_log
        render_footer
      end

      private

      def render_header(client)
        text = "Host: #{client.config[:host]} | User: #{client.config[:username]} | DB: #{client.config[:database]}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.header_h, title: 'Connection Info', align: :center) do
          text
        end
      end

      def render_main
        left = build_box(@layout.left_w, 'DB/Table Tree', 'Tables will appear here')
        right = build_box(@layout.right_w, 'Record/Structure View', 'Data will appear here')

        render_side_by_side(left, right)
      end

      def build_box(width, title, content)
        TTY::Box.frame(
          width: width, height: @layout.main_h, title: title, align: :left
        ) { content }
      end

      def render_side_by_side(left_box, right_box)
        left_lines = left_box.split("\n")
        right_lines = right_box.split("\n")

        left_lines.zip(right_lines).each do |left, right|
          puts "#{left} #{right}"
        end
      end

      def render_log
        puts TTY::Box.frame(width: @layout.width, height: @layout.log_h, title: 'SQL Log / Input', align: :left) do
          'Last SQL: SELECT 1'
        end
      end

      def render_footer
        puts TTY::Box.frame(width: @layout.width, height: @layout.footer_h, title: 'Footer', align: :center) do
          ' [q] Quit | [Tab] Switch Focus '
        end
      end
    end
  end
end
