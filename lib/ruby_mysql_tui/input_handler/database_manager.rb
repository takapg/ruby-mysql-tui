# frozen_string_literal: true

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

        return cancel_deletion(state) unless prompt.yes?("本当にデータベース '#{db_name}' を削除しますか？ (y/N)")

        execute_drop_database(state, client, db_name)
      rescue Mysql2::Error => e
        handle_drop_error(prompt, e, state)
      end

      private_class_method def cancel_deletion(state)
        state[:status_message] = 'Deletion cancelled'
        state
      end

      private_class_method def execute_drop_database(state, client, db_name)
        client.drop_database(db_name)
        state[:items] = client.list_databases
        state[:selected_index] = state[:selected_index].clamp(0, [0, state[:items].size - 1].max)
        state[:status_message] = "Database '#{db_name}' deleted successfully"
        state
      end

      private_class_method def handle_drop_error(prompt, e, state)
        RubyMysqlTui.logger.error("Database Drop Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end
    end
  end
end
