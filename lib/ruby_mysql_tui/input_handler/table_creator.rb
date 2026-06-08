# frozen_string_literal: true

require_relative 'table_executor'
require_relative 'table_error_handler'

module RubyMysqlTui
  module InputHandler
    # TableCreator は テーブル作成操作を提供します。
    module TableCreator
      module_function

      def create(state, client, prompt)
        name = prompt.ask('作成するテーブル名を入力してください:')
        return state if name.nil? || name.strip.empty?

        TableExecutor.execute_create_table(state, client, prompt, name.strip)
      rescue Mysql2::Error => e
        TableErrorHandler.handle_create_error(prompt, e)
        state
      end
    end
  end
end
