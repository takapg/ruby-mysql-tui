# frozen_string_literal: true

require_relative 'record_executor'
require_relative 'record_prompt'
require_relative 'record_retry_handler'
require_relative 'record_clone_manager'
require_relative 'record_toggle_manager'
require_relative 'record_external_editor'

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      def self.handle_clone_record(state, client, prompt)
        RecordCloneManager.handle_clone_record(state, client, prompt)
      end

      def self.handle_edit_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record, pk_column = fetch_edit_context(state, client)
        return state unless record

        if pk_column.nil?
          RecordPrompt.warn_pk_missing(prompt)
          return state
        end

        execute_edit_action(state, client, record, pk_column, prompt)
        state
      end

      def self.fetch_edit_context(state, client)
        [state[:records][state[:selected_record_index]], client.primary_key_for(state[:selected_table])]
      end

      def self.execute_edit_action(state, client, record, pk_column, prompt)
        if state[:view_mode] == :record_detail
          direct_edit(state, client, record, pk_column, prompt)
        else
          edit_and_update(state, client, record, pk_column, prompt)
        end
      end

      def self.direct_edit(state, client, record, pk_column, prompt)
        col_idx = state[:selected_column_index] || 0
        column = record.keys[col_idx]
        return if column.nil?

        structure = client.list_table_structure(state[:selected_table])
        pk_cols = RecordPrompt.identify_primary_keys(structure, pk_column)

        return RecordPrompt.warn_pk_not_editable(prompt) if pk_cols.include?(column)

        context = {
          record: record, pk_column: pk_column, pk_cols: pk_cols, column: column
        }
        prompt_and_update_direct(state, client, prompt, context)
      end

      def self.prompt_and_update_direct(state, client, prompt, context)
        value = prompt.ask("新しい値を入力してください (#{context[:column]}):")
        return if value.nil?

        info = {
          pk_col: context[:pk_column],
          pk_val: context[:record][context[:pk_column]],
          pk_cols: context[:pk_cols],
          col: context[:column],
          val: value
        }
        perform_update(state, client, prompt, info)
      end

      def self.handle_create_record(state, client, prompt)
        return state unless can_manage_record?(state)

        cols = client.list_columns(state[:selected_table])
        struct = client.list_table_structure(state[:selected_table])
        data = RecordPrompt.prompt_for_record_data(cols, prompt, {}, struct)
        return state if data.nil? || data.empty?

        RecordRetryHandler.execute_insert_with_retry(state, client, prompt, data, { columns: cols, structure: struct })
        state
      end

      def self.handle_delete_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        if RecordExecutor.confirm_and_delete(state, client, prompt, record, pk_column)
          state[:selected_record_index] = 0
          state[:view_mode] = :records if state[:view_mode] == :record_detail
        end
        state
      end

      def self.can_manage_record?(state)
        state[:focus] == :right && %i[records record_detail].include?(state[:view_mode]) && !state[:records].nil?
      end

      def self.edit_and_update(state, client, record, pk_column, prompt)
        structure = client.list_table_structure(state[:selected_table])
        result = RecordPrompt.prompt_for_edit(record, prompt, pk_column, structure)
        return if result.nil?

        column, value = result

        pk_cols = RecordPrompt.identify_primary_keys(structure, pk_column)
        info = { pk_col: pk_column, pk_val: record[pk_column], pk_cols: pk_cols, col: column, val: value }
        perform_update(state, client, prompt, info)
      end

      def self.perform_update(state, client, prompt, info)
        if info[:pk_cols].include?(info[:col])
          RecordPrompt.warn_pk_not_editable(prompt)
          return
        end

        RecordRetryHandler.execute_update_with_retry(state, client, prompt, info)
      end

      def self.handle_all_records_toggle(state, client)
        RecordToggleManager.handle_all_records_toggle(state, client)
      end

      def self.handle_external_edit(state, client, prompt)
        RecordExternalEditor.handle_external_edit(state, client, prompt)
      end
    end
  end
end
