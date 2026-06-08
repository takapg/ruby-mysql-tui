# frozen_string_literal: true

require_relative 'deletable'
require_relative 'table_executor'

module RubyMysqlTui
  module InputHandler
    # TableDropper は テーブル削除操作を提供します。
    module TableDropper
      module_function

      def drop(state, client, prompt)
        table_name = state[:items][state[:selected_index]]
        return state if table_name.nil?

        return Deletable.cancel_deletion(state) unless prompt.yes?("本当にテーブル '#{table_name}' を削除しますか？ (y/N)")

        TableExecutor.execute_drop_table(state, client, table_name)
      rescue Mysql2::Error => e
        Deletable.handle_drop_error(prompt, e, state, 'Table')
      end
    end
  end
end
