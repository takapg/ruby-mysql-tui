# frozen_string_literal: true

require 'tempfile'
require 'shellwords'

module RubyMysqlTui
  module InputHandler
    # ValueViewer は フィールド値を外部ビューア（PAGER）で表示する機能を提供します。
    module ValueViewer
      module_function

      def view_value(value)
        return if value.nil?

        file = Tempfile.new(['tui_value', '.txt'])
        begin
          write_and_view(file, value)
        ensure
          file.close
          file.unlink
        end
      end

      private_class_method def write_and_view(file, value)
        file.write(value.to_s)
        file.flush
        pager = ENV['PAGER'] || 'less'
        system(*Shellwords.split(pager), file.path)
      end
    end
  end
end
