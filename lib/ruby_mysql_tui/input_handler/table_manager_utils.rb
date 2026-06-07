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
    end
  end
end
