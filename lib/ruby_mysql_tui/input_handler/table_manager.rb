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

    def handle_drop_table(state, client, prompt)
      table_name = state[:items][state[:selected_index]]
      return state if table_name.nil?

      unless prompt.yes?("本当にテーブル '#{table_name}' を削除しますか？ (y/N)")
        state[:status_message] = 'Deletion cancelled'
        return state
      end

      client.drop_table(table_name)
      state[:items] = client.list_tables(state[:selected_db])
      state[:selected_index] = state[:selected_index].clamp(0, [0, state[:items].size - 1].max)
      state[:status_message] = "Table '#{table_name}' deleted successfully"
      state
    rescue Mysql2::Error => e
      RubyMysqlTui.logger.error("Table Drop Error: #{e.message}")
      prompt.error("エラーが発生しました: #{e.message}")
      state
    end
  end
  end
end
