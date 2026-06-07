# frozen_string_literal: true

require_relative 'sql_editor'
require_relative 'record_prompt'
require_relative 'record_validator'

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
        return state unless RecordValidator.long_text_type?(column, structure)

        pk_cols = RecordPrompt.identify_primary_keys(structure, pk_column)
        return state if pk_column_not_editable?(column, pk_cols, prompt)

        context = { record: record, column: column, pk_column: pk_column, pk_cols: pk_cols }
        execute_edit(state, client, prompt, context)
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

      def execute_edit(state, client, prompt, context)
        new_value = perform_editor_edit(context)
        return unless new_value && new_value != context[:record][context[:column]]

        info = build_update_info(context, new_value)
        RecordManager.perform_update(state, client, prompt, info)
      end

      def perform_editor_edit(context)
        editor = ENV['EDITOR'] || 'vi'
        SqlEditor.edit_in_editor(editor, context[:record][context[:column]])
      end

      def build_update_info(context, new_value)
        {
          pk_col: context[:pk_column],
          pk_val: context[:record][context[:pk_column]],
          pk_cols: context[:pk_cols],
          col: context[:column],
          val: new_value
        }
      end
    end
  end
end
