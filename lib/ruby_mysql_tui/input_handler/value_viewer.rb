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

        Tempfile.create(['tui_value', '.txt']) do |file|
          file.write(value.to_s)
          file.flush
          pager = ENV['PAGER'] || 'less'
          system("#{Shellwords.escape(pager)} #{Shellwords.escape(file.path)}")
        end
      end
    end
  end
end
