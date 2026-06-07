# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TableManagerUtils provides private helper methods used by TableManager.
    module TableManagerUtils
      module_function

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

      # Executes the add‑column operation and sets a status message.
      def add_column_and_set_status(state, client, table_name, col_name, type_string)
        result = TableExecutor.execute_add_column(state, client, table_name, col_name, type_string)
        result[:status_message] = "Column '#{col_name}' added to '#{table_name}' successfully"
        result
      end

      # Executes the modify‑column operation and sets a status message.
      def modify_column_and_set_status(state, client, table_name, old_name, type_string)
        result = TableExecutor.execute_modify_column(state, client, table_name, old_name, type_string)
        result[:status_message] = "Column '#{old_name}' modified successfully"
        result
      end

      # Builds the type string with optional NULL/NOT NULL constraint.
      def build_type_string(prompt, type)
        if RubyMysqlTui::InputHandler::TablePromptHelper::NULL_PROMPT_ENABLED
          null_allowed = prompt.yes?('NULLを許容しますか？')
          null_allowed ? "#{type} NULL" : "#{type} NOT NULL"
        else
          type
        end
      end
    end
  end
end
