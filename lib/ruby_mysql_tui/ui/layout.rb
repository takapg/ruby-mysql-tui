# frozen_string_literal: true

require 'tty-screen'

module RubyMysqlTui
  module UI
    # Layout はターミナルのサイズに基づいた各セクションの寸法を管理します。
    class Layout
      attr_reader :width, :height, :header_h, :footer_h, :log_h, :main_h, :left_w, :right_w

      def initialize
        update_dimensions
      end

      # ターミナルの現在のサイズに基づいて寸法を再計算します。
      def update_dimensions
        @width = TTY::Screen.width
        @height = TTY::Screen.height
        @header_h = 3
        @footer_h = 3
        @log_h = 5
        @main_h = @height - @header_h - @footer_h - @log_h
        @left_w = (@width * 0.3).to_i
        @right_w = @width - @left_w - 1
      end
    end
  end
end
# frozen_string_literal: true

require 'tty-box'
require_relative 'layout'

module RubyMysqlTui
  module UI
    # Renderer は Layout に基づいて TUI 画面を描画します。
    class Renderer
      def initialize(layout)
        @layout = layout
      end

      # 画面全体をレンダリングします。
      def render(client)
        @layout.update_dimensions
        # 画面クリアとカーソルをホームポジションへ
        print "\e[2J\e[H"

        # ヘッダーの描画
        header_text = "Host: #{client.config[:host]} | User: #{client.config[:username]} | DB: #{client.config[:database]}"
        puts TTY::Box.frame(width: @layout.width, height: @layout.header_h, title: 'Connection Info', align: :center) do
          header_text
        end

        # メインエリア（左右2ペイン）の描画
        left_box = TTY::Box.frame(width: @layout.left_w, height: @layout.main_h, title: 'DB/Table Tree', align: :left) do
          "Tables will appear here"
        end
        right_box = TTY::Box.frame(width: @layout.right_w, height: @layout.main_h, title: 'Record/Structure View', align: :left) do
          "Data will appear here"
        end

        left_lines = left_box.split("\n")
        right_lines = right_box.split("\n")

        (0...@layout.main_h).each do |i|
          puts "#{left_lines[i]} #{right_lines[i]}"
        end

        # SQLログエリアの描画
        puts TTY::Box.frame(width: @layout.width, height: @layout.log_h, title: 'SQL Log / Input', align: :left) do
          "Last SQL: SELECT 1"
        end

        # フッターの描画
        puts TTY::Box.frame(width: @layout.width, height: @layout.footer_h, title: 'Footer', align: :center) do
          " [q] Quit | [Tab] Switch Focus "
        end
      end
    end
  end
end
