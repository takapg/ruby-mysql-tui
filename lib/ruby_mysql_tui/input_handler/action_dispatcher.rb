# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # ActionDispatcher は ActionHandler から委譲された具体的なアクション処理を提供します。
    module ActionDispatcher
      module_function

      def handle_rename_action(state, client, prompt)
        if state[:focus] == :left && state[:view_mode] == :tables
          TableManager.handle_rename_table(state, client, prompt)
        elsif state[:focus] == :right && state[:view_mode] == :table_structure
          TableManager.handle_rename_column(state, client, prompt)
        else
          state
        end
      end

      def handle_truncate_action(state, client, prompt)
        if state[:focus] == :left && state[:view_mode] == :tables
          TableManager.handle_truncate_table(state, client, prompt)
        else
          state
        end
      end

      def handle_modify_action(state, client, prompt)
        if state[:focus] == :right && state[:view_mode] == :table_structure
          TableManager.handle_modify_column(state, client, prompt)
        else
          state
        end
      end

      def handle_delete_action(state, client, prompt)
        case state[:view_mode]
        when :databases
          DatabaseManager.handle_drop_database(state, client, prompt)
        when :tables
          TableManager.handle_drop_table(state, client, prompt)
        when :table_structure
          TableManager.handle_drop_column(state, client, prompt)
        else
          RecordManager.handle_delete_record(state, client, prompt)
        end
      end

      def handle_new_record_action(state, client, prompt)
        case state[:view_mode]
        when :databases then DatabaseManager.handle_create_database(state, client, prompt)
        when :tables then TableManager.handle_create_table(state, client, prompt)
        when :table_structure then TableManager.handle_add_column(state, client, prompt)
        else RecordManager.handle_create_record(state, client, prompt)
        end
      end

      def handle_view_value_action(state)
        return state unless state[:view_mode] == :record_detail

        records = state[:records] || []
        record = records[state[:selected_record_index] || 0]
        return state unless record

        column_name = record.keys[state[:selected_column_index] || 0]
        ValueViewer.view_value(record[column_name])
        state
      end
    end
  end
end
