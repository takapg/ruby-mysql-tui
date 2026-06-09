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
        calculate_heights
        calculate_widths
      end

      private

      def calculate_heights
        # TTY::Screen may raise errors in non‑interactive test environments.
        # Fallback to sensible defaults when height cannot be obtained.
        @height = if TTY::Screen.respond_to?(:height)
                    begin
                      TTY::Screen.height
                    rescue StandardError
                      24
                    end
                  else
                    24
                  end
        @header_h = 3
        @footer_h = 3
        @log_h = 5
        @main_h = [@height - @header_h - @footer_h - @log_h, 0].max
      end

      def calculate_widths
        # Similar fallback for width.
        @width = if TTY::Screen.respond_to?(:width)
                   begin
                     TTY::Screen.width
                   rescue StandardError
                     80
                   end
                 else
                   80
                 end
        @left_w = [(@width * 0.3).to_i, 10].max.clamp(0, [@width - 2, 0].max)
        @right_w = [@width - @left_w - 1, 0].max
      end
    end
  end
end
