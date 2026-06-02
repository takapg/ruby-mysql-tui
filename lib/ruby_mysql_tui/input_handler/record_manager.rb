# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      module_function

      def handle_edit_record(state, client, prompt)
        return state unless can_edit_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        edit_and_update(state, client, record, pk_column, prompt)
        state
      end

      def handle_delete_record(state, client, prompt)
        return state unless can_delete_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        confirm_and_delete(state, client, record, pk_column, prompt)
        state
      end

      def can_edit_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def can_delete_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def edit_and_update(state, client, record, pk_column, prompt)
        columns = record.keys
        column_to_edit = prompt.select('編集するカラムを選択してください:', columns)
        new_value = prompt.ask("新しい値を入力してください (#{column_to_edit}):") { |q| q.required true }

        return if new_value.nil?

        begin
          client.update_record(state[:selected_table], pk_column, record[pk_column], column_to_edit, new_value)
          state[:records] = client.list_records(state[:selected_table], state[:records_offset] || 0)
        rescue Mysql2::Error => e
          RubyMysqlTui.logger.error("Failed to update record: #{e.message}")
          prompt.say("更新に失敗しました: #{e.message}", color: :red)
        end
      end

      def confirm_and_delete(state, client, record, pk_column, prompt)
        return unless prompt.yes?('本当にこのレコードを削除しますか？ (y/N)')

        table = state[:selected_table]
        begin
          client.delete_record(table, pk_column, record[pk_column])
          state[:records] = client.list_records(table, state[:records_offset] || 0)
          state[:selected_record_index] = 0
        rescue Mysql2::Error => e
          RubyMysqlTui.logger.error("Failed to delete record: #{e.message}")
        end
      end
    end
  end
end
