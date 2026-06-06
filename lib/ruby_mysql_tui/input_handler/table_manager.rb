# frozen_string_literal: true

require_relative 'deletable'

module RubyMysqlTui
  module InputHandler
    # TableManager は テーブルの作成などの操作を提供します。
    module TableManager
      COLUMN_TYPES = ['INT', 'VARCHAR(255)', 'TEXT', 'DATETIME', 'DATE'].freeze

      module_function

      def handle_create_table(state, client, prompt)
        name = prompt.ask('作成するテーブル名を入力してください:')
        return state if name.nil? || name.strip.empty?

        execute_create_table(state, client, prompt, name.strip)
      rescue Mysql2::Error => e
        handle_create_error(prompt, e)
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

      def handle_rename_table(state, client, prompt)
        table_name = state[:items][state[:selected_index]]
        return state if table_name.nil?

        new_name = prompt.ask("テーブル '#{table_name}' の新しい名前を入力してください:")
        return state if new_name.nil? || new_name.strip.empty?

        execute_rename_table(state, client, table_name, new_name.strip)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Table Rename Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end

      def handle_truncate_table(state, client, prompt)
        table_name = state[:items][state[:selected_index]]
        return state if table_name.nil?

        return cancel_truncation(state) unless prompt.yes?("本当にテーブル '#{table_name}' を切り捨てますか？ (y/N)")

        execute_truncate_table(state, client, table_name)
      rescue Mysql2::Error => e
        handle_truncate_error(prompt, e)
        state
      end

      private_class_method def execute_create_table(state, client, prompt, name)
        cols = collect_column_definitions(prompt)
        client.create_table(name, cols)
        state[:items] = client.list_tables(state[:selected_db])
        state
      end

      private_class_method def handle_create_error(prompt, error)
        RubyMysqlTui.logger.error("Table Creation Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end

      private_class_method def handle_truncate_error(prompt, error)
        RubyMysqlTui.logger.error("Table Truncate Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end

      private_class_method def cancel_truncation(state)
        state[:status_message] = 'Truncation cancelled'
        state
      end

      private_class_method def execute_rename_table(state, client, old_name, new_name)
        client.rename_table(old_name, new_name)
        state[:items] = client.list_tables(state[:selected_db])
        state[:status_message] = "Table '#{old_name}' renamed to '#{new_name}' successfully"
        state
      end

      private_class_method def execute_drop_table(state, client, table_name)
        client.drop_table(table_name)
        state = Deletable.update_state_after_deletion(state, client.list_tables(state[:selected_db]))
        state[:status_message] = "Table '#{table_name}' deleted successfully"
        state
      end

      private_class_method def execute_truncate_table(state, client, table_name)
        client.truncate_table(table_name)
        state[:status_message] = "Table '#{table_name}' truncated successfully"
        state
      end

      private_class_method def collect_column_definitions(prompt)
        columns = []
        loop do
          col = prompt_for_single_column(prompt)
          break if col.nil?

          columns << col
          break unless prompt.yes?('さらにカラムを追加しますか？')
        end
        columns
      end

      private_class_method def prompt_for_single_column(prompt)
        name = prompt.ask('カラム名を入力してください:')
        return nil if name.nil? || name.strip.empty?

        { name: name.strip, type: prompt.select('データ型を選択してください:', COLUMN_TYPES) }
      end
    end
  end
end
