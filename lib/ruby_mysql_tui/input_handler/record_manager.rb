# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      module_function

      def handle_delete_record(state, client)
        return state unless can_delete_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        confirm_and_delete(state, client, record, pk_column)
        state
      end

      def can_delete_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def confirm_and_delete(state, client, record, pk_column)
        return unless TTY::Prompt.new.yes?('本当にこのレコードを削除しますか？ (y/N)')

        table = state[:selected_table]
        client.delete_record(table, pk_column, record[pk_column])
        state[:records] = client.list_records(table, state[:records_offset] || 0)
        state[:selected_record_index] = 0
      end
    end
  end
end
