# frozen_string_literal: true

require_relative 'deletable'
require_relative 'table_prompt_helper'
require_relative 'table_executor'
require_relative 'table_error_handler'

module RubyMysqlTui
  module InputHandler
    # TableManager は テーブルの作成などの操作を提供します。
    module TableManager
      module_function

      def handle_create_table(state, client, prompt)
        name = prompt.ask('作成するテーブル名を入力してください:')
        return state if name.to_s.strip.empty?

        TableExecutor.execute_create_table(state, client, prompt, name.strip)
      rescue Mysql2::Error => e
        TableErrorHandler.handle_create_error(prompt, e)
        state
      end

      def handle_drop_table(state, client, prompt)
        return state if (table_name = state[:items][state[:selected_index]]).nil?

        return Deletable.cancel_deletion(state) unless prompt.yes?("本当にテーブル '#{table_name}' を削除しますか？ (y/N)")

        TableExecutor.execute_drop_table(state, client, table_name)
      rescue Mysql2::Error => e
        Deletable.handle_drop_error(prompt, e, state, 'Table')
      end

      def handle_rename_table(state, client, prompt)
        return state if (table_name = state[:items][state[:selected_index]]).nil?

        new_name = prompt.ask("テーブル '#{table_name}' の新しい名前を入力してください:")
        return state if new_name.to_s.strip.empty?

        TableExecutor.execute_rename_table(state, client, table_name, new_name.strip)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Table Rename Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end

      def handle_truncate_table(state, client, prompt)
        return state if (table_name = state[:items][state[:selected_index]]).nil?

        return cancel_truncation(state) unless prompt.yes?("本当にテーブル '#{table_name}' を切り捨てますか？ (y/N)")

        TableExecutor.execute_truncate_table(state, client, table_name)
      rescue Mysql2::Error => e
        TableErrorHandler.handle_truncate_error(prompt, e)
        state
      end

      def handle_add_column(state, client, prompt)
        table_name = state[:selected_table]
        return state if table_name.nil?

        col_name, type_with_null = TablePromptHelper.prompt_for_column_details(prompt)
        return state if col_name.nil?

        TableExecutor.execute_add_column(state, client, table_name, col_name, type_with_null)
      rescue Mysql2::Error => e
        TableErrorHandler.handle_add_column_error(prompt, e)
        state
      end


      def handle_rename_column(state, client, prompt)
        return state if (column_info = fetch_selected_column(state)).nil?

        old_name = column_info['Field']
        new_name = prompt.ask("カラム '#{old_name}' の新しい名前を入力してください:")
        return state if new_name.to_s.strip.empty?

        TableExecutor.execute_rename_column(state, client, state[:selected_table], old_name, new_name.strip)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Column Rename Error: #{e.message}")
        prompt.error("エラーが発生しました: #{e.message}")
        state
      end

      def handle_drop_column(state, client, prompt)
        return state if (column_info = fetch_selected_column(state)).nil?

        column_name = column_info['Field']
        return state if primary_key_error?(column_info, prompt, column_name)
        return Deletable.cancel_deletion(state) unless prompt.yes?("本当にカラム '#{column_name}' を削除しますか？ (y/N)")

        TableExecutor.execute_drop_column(state, client, state[:selected_table], column_name)
      rescue Mysql2::Error => e
        Deletable.handle_drop_error(prompt, e, state, 'Column')
      end

      def handle_modify_column(state, client, prompt)
        return state if (column_info = fetch_selected_column(state)).nil?

        old_name = column_info['Field']
        type_with_null = TablePromptHelper.prompt_for_type_with_null(prompt, "カラム '#{old_name}' の新しいデータ型を選択してください:")
        TableExecutor.execute_modify_column(state, client, state[:selected_table], old_name, type_with_null)
      rescue Mysql2::Error => e
        TableErrorHandler.handle_modify_column_error(prompt, e)
        state
      end


      def fetch_selected_column(state)
        structure = state[:records]
        selected_idx = state[:selected_record_index] || 0
        structure[selected_idx]
      end

      def primary_key_error?(column_info, prompt, column_name)
        return false unless column_info['Key'] == 'PRI'

        prompt.error("主キーカラム '#{column_name}' は削除できません。")
        true
      end

      def cancel_truncation(state)
        state[:status_message] = 'Truncation cancelled'
        state
      end

      private_class_method(
        :fetch_selected_column, :primary_key_error?,
        :cancel_truncation
      )
    end
  end
end
