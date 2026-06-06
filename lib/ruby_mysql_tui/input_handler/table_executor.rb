# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TableExecutor は テーブル操作の実際の実行ロジックを提供します。
    module TableExecutor
      module_function

      def execute_create_table(state, client, prompt, name)
        cols = TablePromptHelper.collect_column_definitions(prompt)
        client.create_table(name, cols)
        state[:items] = client.list_tables(state[:selected_db])
        state
      end

      def execute_rename_table(state, client, old_name, new_name)
        client.rename_table(old_name, new_name)
        state[:items] = client.list_tables(state[:selected_db])
        state[:status_message] = "Table '#{old_name}' renamed to '#{new_name}' successfully"
        state
      end

      def execute_drop_table(state, client, table_name)
        client.drop_table(table_name)
        state = Deletable.update_state_after_deletion(state, client.list_tables(state[:selected_db]))
        state[:status_message] = "Table '#{table_name}' deleted successfully"
        state
      end

      def execute_truncate_table(state, client, table_name)
        client.truncate_table(table_name)
        state[:status_message] = "Table '#{table_name}' truncated successfully"
        state
      end

      def execute_add_column(state, client, table_name, col_name, type)
        client.add_column(table_name, col_name, type)
        state[:records] = client.list_table_structure(table_name)
        state[:status_message] = "Column '#{col_name}' added to '#{table_name}' successfully"
        state
      end

      def execute_drop_column(state, client, table_name, column_name)
        client.drop_column(table_name, column_name)
        state[:records] = client.list_table_structure(table_name)
        state[:selected_record_index] = 0
        state[:records_offset] = 0
        state[:status_message] = "Column '#{column_name}' deleted successfully"
        state
      end
    end
  end
end
