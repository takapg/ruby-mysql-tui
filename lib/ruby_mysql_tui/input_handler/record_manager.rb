# frozen_string_literal: true

require_relative 'record_executor'

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      module_function

      def handle_edit_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        edit_and_update(state, client, record, pk_column, prompt)
        state
      end

      def handle_create_record(state, client, prompt)
        return state unless can_manage_record?(state)

        columns = client.list_columns(state[:selected_table])
        data = prompt_for_record_data(columns, prompt)
        return state if data.nil? || data.empty?

        RecordExecutor.execute_insert(state, client, prompt, columns, data)
        state
      end

      def handle_delete_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        RecordExecutor.confirm_and_delete(state, client, record, pk_column, prompt)
        state
      end

      def prompt_for_record_data(columns, prompt, default_data = {})
        columns.each_with_object({}) do |col, data|
          val = prompt.ask("値を入力してください (#{col}):", default: default_data[col])
          return nil if val.nil?

          data[col] = val
        end
      end

      def can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def edit_and_update(state, client, record, pk_column, prompt)
        column, value = prompt_for_edit(record, prompt, pk_column)
        return if value.nil?

        RecordExecutor.execute_update(
          state, client, prompt, pk_col: pk_column, pk_val: record[pk_column], col: column, val: value
        )
      end

      def prompt_for_edit(record, prompt, pk_column = nil)
        editable_columns = record.keys - [pk_column]
        if editable_columns.empty?
          prompt.say('編集可能なカラムがありません', color: :yellow)
          return nil
        end

        column = prompt.select('編集するカラムを選択してください:', editable_columns)
        value = prompt.ask("新しい値を入力してください (#{column}):", default: record[column]) { |q| q.required true }
        [column, value]
      end
    end
  end
end
