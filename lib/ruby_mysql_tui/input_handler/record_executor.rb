# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordExecutor は レコードのDB操作とリトライロジックを提供します。
    module RecordExecutor
      extend self

      def execute_insert(state, client, prompt, data)
        client.insert_record(state[:selected_table], data)
        refresh_records_safe(state, client, prompt)
      end

      def confirm_and_delete(state, client, prompt, record, pk_column)
        return set_cancellation_message(state) unless prompt.yes?('本当にこのレコードを削除しますか？ (y/N)')

        perform_deletion(state, client, prompt, record, pk_column)
        state[:status_message] = 'Record deleted successfully'
        true
      rescue Mysql2::Error => e
        handle_deletion_error(state, e)
        false
      end

      def execute_update(state, client, prompt, info)
        if info[:pk_col].nil?
          prompt.say('主キーが指定されていないため、更新できません', color: :red)
          return
        end

        if info[:col] == info[:pk_col]
          prompt.say('主キーは編集できません', color: :red)
          return
        end

        client.update_record(state[:selected_table], info[:pk_col], info[:pk_val], info[:col], info[:val])
        refresh_records_safe(state, client, prompt)
      end

      def refresh_records_safe(state, client, prompt)
        state[:records] = client.list_records(state[:selected_table], state[:records_offset] || 0)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to refresh records: #{e.message}")
        prompt.say("更新は成功しましたが、一覧の再取得に失敗しました: #{e.message}", color: :yellow)
      end

      private

      def set_cancellation_message(state)
        state[:status_message] = 'Deletion cancelled'
        false
      end

      def perform_deletion(state, client, prompt, record, pk_column)
        client.delete_record(state[:selected_table], pk_column, record[pk_column])
        refresh_records_safe(state, client, prompt)
      end

      def handle_deletion_error(state, error)
        RubyMysqlTui.logger.error("Failed to delete record: #{error.message}")
        state[:status_message] = "Failed to delete record: #{error.message}"
      end
    end
  end
end
