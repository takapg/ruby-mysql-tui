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
    end
  end
end
