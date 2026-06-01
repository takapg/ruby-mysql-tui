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
```

```ruby
lib/ruby_mysql_tui/ui/renderer.rb
<<<<<<< SEARCH
