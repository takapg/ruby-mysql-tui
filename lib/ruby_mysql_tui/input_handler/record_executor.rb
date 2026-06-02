# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordExecutor は レコードのDB操作とリトライロジックを提供します。
    module RecordExecutor
      module_function

      def execute_insert(state, client, prompt, data)
        client.insert_record(state[:selected_table], data)
        refresh_records_safe(state, client, prompt)
      end

      def confirm_and_delete(state, client, prompt, record, pk_column)
        return false unless prompt.yes?('本当にこのレコードを削除しますか？ (y/N)')

        table = state[:selected_table]
        client.delete_record(table, pk_column, record[pk_column])
        refresh_records_safe(state, client, prompt)
        true
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to delete record: #{e.message}")
        false
      end

      def execute_update(state, client, prompt, info)
        return if info[:col] == info[:pk_col]

        client.update_record(state[:selected_table], info[:pk_col], info[:pk_val], info[:col], info[:val])
        refresh_records_safe(state, client, prompt)
      end

      def refresh_records_safe(state, client, prompt)
        state[:records] = client.list_records(state[:selected_table], state[:records_offset] || 0)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to refresh records: #{e.message}")
        prompt.say("更新は成功しましたが、一覧の再取得に失敗しました: #{e.message}", color: :yellow)
      end
    end
  end
end
