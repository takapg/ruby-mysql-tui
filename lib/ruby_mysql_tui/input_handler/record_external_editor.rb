# frozen_string_literal: true

require_relative 'sql_editor'
require_relative 'record_prompt'

module RubyMysqlTui
  module InputHandler
    # RecordExternalEditor は 外部エディタを使用したレコード編集を提供します。
    module RecordExternalEditor
      module_function

      def handle_external_edit(state, client, prompt)
        return state unless can_edit?(state)

        record, pk_column = RecordManager.fetch_edit_context(state, client)
        column = get_selected_column(state, record)
        return state unless record && column

        structure = client.list_table_structure(state[:selected_table])
        pk_cols = RecordPrompt.identify_primary_keys(structure, pk_column)

        return state if pk_column_not_editable?(column, pk_cols, prompt)

        execute_edit(state, client, prompt, record, pk_column, pk_cols, column)
        state
      end

      def can_edit?(state)
        RecordManager.can_manage_record?(state) && state[:view_mode] == :record_detail
      end

      def get_selected_column(state, record)
        return nil unless record
        record.keys[state[:selected_column_index] || 0]
      end

      def pk_column_not_editable?(column, pk_cols, prompt)
        if pk_cols.include?(column)
          RecordPrompt.warn_pk_not_editable(prompt)
          return true
        end
        false
      end

      def execute_edit(state, client, prompt, record, pk_column, pk_cols, column)
        editor = ENV['EDITOR'] || 'vi'
        new_value = SqlEditor.edit_in_editor(editor, record[column])

        if new_value && new_value != record[column]
          info = { pk_col: pk_column, pk_val: record[pk_column], pk_cols: pk_cols, col: column, val: new_value }
          RecordManager.perform_update(state, client, prompt, info)
        end
      end
    end
  end
end
