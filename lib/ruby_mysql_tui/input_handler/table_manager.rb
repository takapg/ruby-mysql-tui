# frozen_string_literal: true

require_relative 'deletable'

module RubyMysqlTui
  module InputHandler
    # TableManager は テーブルの作成などの操作を提供します。
    module TableManager
      module_function

      def handle_create_table(state, client, prompt)
        name = prompt.ask('作成するテーブル名を入力してください:')
        return state if name.nil? || name.strip.empty?

        cols = prompt_for_columns(prompt)
        client.create_table(name.strip, cols)
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

        return Deletable.cancel_deletion(state) unless prompt.yes?("本当にテーブル '#{table_name}' を削除しますか？ (y/N)")

        execute_drop_table(state, client, table_name)
      rescue Mysql2::Error => e
        Deletable.handle_drop_error(prompt, e, state, 'Table')
      end

      private_class_method def execute_drop_table(state, client, table_name)
        client.drop_table(table_name)
        state = Deletable.update_state_after_deletion(state, client.list_tables(state[:selected_db]))
        state[:status_message] = "Table '#{table_name}' deleted successfully"
        state
      end

      private_class_method def prompt_for_columns(prompt)
        input = prompt.ask('追加するカラム名（カンマ区切り、任意）:')
        return [] if input.nil?
        input.split(',').map(&:strip).reject(&:empty?)
      end
    end
  end
end
