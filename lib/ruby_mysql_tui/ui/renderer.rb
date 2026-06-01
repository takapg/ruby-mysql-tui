# frozen_string_literal: true

require 'tty-box'
require 'tty-table'
require_relative 'layout'
require_relative 'content_builder'

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
        render_log(client, state)
        render_footer
      end

      private

      def render_header(client)
        text = "Host: #{client.config[:host]} | User: #{client.config[:username]} | DB: #{client.config[:database]}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.header_h) { text }
      end

      def render_main(state)
        left = build_box(@layout.left_w, left_content(state), state[:focus] == :left)
        right = build_box(@layout.right_w, right_content(state), state[:focus] == :right)

        render_side_by_side(left, right)
      end

      def left_content(state)
        ContentBuilder.build_list_text(state[:items], state[:selected_index], @layout.left_w)
      end

      def right_content(state)
        ContentBuilder.build_right_text(state, @layout.right_w, @layout.main_h)
      end

      def build_box(width, content, focused)
        TTY::Box.frame(
          width: width, height: @layout.main_h,
          style: { border: { fg: focused ? :cyan : :white } }
        ) { content }
      end

      def render_side_by_side(left_box, right_box)
        left_lines = left_box.split("\n", -1)
        right_lines = right_box.split("\n", -1)
        max_lines = [left_lines.length, right_lines.length].max

        (0...max_lines).each do |i|
          puts "#{left_lines[i]}#{right_lines[i]}"
        end
      end

      def render_log(client, state)
        if state[:sql_mode]
          text = "SQL MODE: #{state[:sql_input]} (Esc to cancel)"
        else
          sql = client.last_sql
          text = sql ? "Last SQL: #{sql}" : 'No SQL executed'
        end
        truncated_text = ContentBuilder.truncate(text, @layout.width - 2)
        puts TTY::Box.frame(width: @layout.width, height: @layout.log_h) { truncated_text }
      end

      def render_footer
        puts TTY::Box.frame(width: @layout.width, height: @layout.footer_h) { ' [q] Quit | [b] Back | [Tab] Switch Focus | [↑/↓] Move | [Enter] Select ' }
      end
    end
  end
end
