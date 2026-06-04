# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TableManager は テーブルの作成などの操作を提供します。
    module TableManager
      module_function

      def handle_create_table(state, client, prompt)
        name = prompt.ask('作成するテーブル名を入力してください:')
        return state if name.nil? || name.strip.empty?

        client.create_table(name.strip)
        state[:items] = client.list_tables(state[:selected_db])
        state
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Table Creation Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end
    end
  end
end
