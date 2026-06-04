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
      def handle_drop_table(state, client, prompt)
        table_name = state[:items][state[:selected_index]]
        return state if table_name.nil?

        return cancel_deletion(state) unless prompt.yes?("本当にテーブル '#{table_name}' を削除しますか？ (y/N)")

        execute_drop_table(state, client, table_name)
      rescue Mysql2::Error => e
        handle_drop_error(prompt, e, state)
      end

      private_class_method def cancel_deletion(state)
        state[:status_message] = 'Deletion cancelled'
        state
      end

      private_class_method def execute_drop_table(state, client, table_name)
        client.drop_table(table_name)
        state[:items] = client.list_tables(state[:selected_db])
        state[:selected_index] = state[:selected_index].clamp(0, [0, state[:items].size - 1].max)
        state[:status_message] = "Table '#{table_name}' deleted successfully"
        state
      end

      private_class_method def handle_drop_error(prompt, e, state)
        RubyMysqlTui.logger.error("Table Drop Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end
    end
  end
end
