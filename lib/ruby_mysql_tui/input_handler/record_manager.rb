# frozen_string_literal: true

require_relative 'record_executor'
require_relative 'record_prompt'
require_relative 'record_retry_handler'

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      def self.handle_clone_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        return state unless record

        data, info = gather_clone_data(state, client, prompt, record)
        return state if data.nil? || data.empty?

        RecordRetryHandler.execute_insert_with_retry(state, client, prompt, data, info)
        state
      end

      def self.gather_clone_data(state, client, prompt, record)
        pk_col = client.primary_key_for(state[:selected_table])
        cols = client.list_columns(state[:selected_table])
        struct = client.list_table_structure(state[:selected_table])
        data = RecordPrompt.prompt_for_record_data(cols, prompt, record.reject { |k, _| k == pk_col }, struct)
        [data, { columns: cols, structure: struct }]
      end

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

        state[:selected_record_index] = 0 if RecordExecutor.confirm_and_delete(state, client, prompt, record, pk_column)
        state
      end

      def self.can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def self.edit_and_update(state, client, record, pk_column, prompt)
        structure = client.list_table_structure(state[:selected_table])
        result = RecordPrompt.prompt_for_edit(record, prompt, pk_column, structure)
        return if result.nil?

        column, value = result
        return if value.nil?

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
        return state unless can_toggle_all_records?(state)

        state[:all_records_mode] = !state[:all_records_mode]
        apply_all_records_mode(state, client)
        state
      end

      def self.can_toggle_all_records?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:selected_table]
      end

      def self.apply_all_records_mode(state, client)
        opts = sort_options(state)
        if state[:all_records_mode]
          state[:records] = client.list_records(
            state[:selected_table], 0, limit: RubyMysqlTui::Client::MAX_RECORDS_LIMIT, **opts
          )
          state[:page_offset] = 0
        else
          state[:page_offset] = state[:records_offset] || 0
          state[:records] = client.list_records(state[:selected_table], state[:page_offset], **opts)
        end
      end

      private_class_method def self.sort_options(state)
        state[:sort_column] ? { sort_column: state[:sort_column], sort_direction: state[:sort_direction] } : {}
      end
    end
  end
end
