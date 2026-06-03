# frozen_string_literal: true

require_relative 'record_executor'
require_relative 'record_prompt'
require_relative 'record_retry_handler'

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      def self.handle_edit_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record

        if pk_column.nil?
          RecordPrompt.warn_pk_missing(prompt)
          return state
        end

        edit_and_update(state, client, record, pk_column, prompt)
        state
      end

      def self.handle_create_record(state, client, prompt)
        return state unless can_manage_record?(state)

        columns = client.list_columns(state[:selected_table])
        structure = client.list_table_structure(state[:selected_table])
        data = RecordPrompt.prompt_for_record_data(columns, prompt, {}, structure)
        return state if data.nil? || data.empty?

        RecordRetryHandler.execute_insert_with_retry(state, client, prompt, data, columns, structure)
        state
      end

      def self.handle_delete_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        state[:selected_record_index] = 0 if RecordExecutor.confirm_and_delete(state, client, prompt, record, pk_column)
        state
      end

      def self.can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def self.edit_and_update(state, client, record, pk_column, prompt)
        structure = client.list_table_structure(state[:selected_table])
        column, value = RecordPrompt.prompt_for_edit(record, prompt, pk_column, structure)
        return if value.nil?

        if column == pk_column
          RecordPrompt.warn_pk_not_editable(prompt)
          return
        end

        info = { pk_col: pk_column, pk_val: record[pk_column], col: column, val: value }
        RecordRetryHandler.execute_update_with_retry(state, client, prompt, info)
      end
    end
  end
end
