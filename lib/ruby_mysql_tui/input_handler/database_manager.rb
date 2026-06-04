# frozen_string_literal: true

require_relative 'deletable'

module RubyMysqlTui
  module InputHandler
    # DatabaseManager は データベースの作成などの操作を提供します。
    module DatabaseManager
      module_function

      def handle_create_database(state, client, prompt)
        name = prompt.ask('作成するデータベース名を入力してください:')
        return state if name.nil? || name.strip.empty?

        client.create_database(name.strip)
        state[:items] = client.list_databases
        state
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Database Creation Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end

      def handle_drop_database(state, client, prompt)
        db_name = state[:items][state[:selected_index]]
        return state if db_name.nil?

        return Deletable.cancel_deletion(state) unless prompt.yes?("本当にデータベース '#{db_name}' を削除しますか？ (y/N)")

        execute_drop_database(state, client, db_name)
      rescue Mysql2::Error => e
        Deletable.handle_drop_error(prompt, e, state, 'Database')
      end

      private_class_method def execute_drop_database(state, client, db_name)
        client.drop_database(db_name)
        state = Deletable.update_state_after_deletion(state, client.list_databases)
        state[:status_message] = "Database '#{db_name}' deleted successfully"
        state
      end
    end
  end
end
