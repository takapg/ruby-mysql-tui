# frozen_string_literal: true

require 'tempfile'
require 'shellwords'

module RubyMysqlTui
  module InputHandler
    # SqlEditor は 外部エディタを使用した SQL 入力機能を提供します。
    module SqlEditor
      module_function

      def open_external_editor(state)
        editor = ENV['EDITOR'] || 'vi'
        edited_sql = edit_in_editor(editor, state[:sql_input])
        state[:sql_input] = edited_sql if edited_sql
        [state, true]
      end

      def edit_in_editor(editor, content)
        temp_file = Tempfile.new(['sql_input', '.sql'])
        begin
          temp_file.write(content || '')
          temp_file.close
          File.read(temp_file.path) if system(*Shellwords.split(editor), temp_file.path)
        ensure
          temp_file.unlink
        end
      end
    end
  end
end
