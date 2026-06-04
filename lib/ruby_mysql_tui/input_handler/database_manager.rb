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

      unless prompt.yes?("本当にデータベース '#{db_name}' を削除しますか？ (y/N)")
        state[:status_message] = 'Deletion cancelled'
        return state
      end

      client.drop_database(db_name)
      state[:items] = client.list_databases
      state[:selected_index] = state[:selected_index].clamp(0, [0, state[:items].size - 1].max)
      state[:status_message] = "Database '#{db_name}' deleted successfully"
      state
    rescue Mysql2::Error => e
      RubyMysqlTui.logger.error("Database Drop Error: #{e.message}")
      prompt.error("エラーが発生しました: #{e.message}")
      state
    end
  end
  end
end
