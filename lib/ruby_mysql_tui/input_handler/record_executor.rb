# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordExecutor は レコードのDB操作とリトライロジックを提供します。
    module RecordExecutor
      module_function

      def execute_insert(state, client, prompt, columns, data)
        retries = 0
        loop do
          client.insert_record(state[:selected_table], data)
          refresh_records_safe(state, client, prompt)
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= 5

          data = retry_insert(e, columns, prompt, data)
          break if data.nil? || data.empty?
        end
      end

      def retry_insert(error, columns, prompt, data)
        RubyMysqlTui.logger.error("Failed to insert record: #{error.message}")
        prompt.say("挿入に失敗しました: #{error.message}", color: :red)
        RecordManager.prompt_for_record_data(columns, prompt, data)
      end

      def confirm_and_delete(state, client, record, pk_column, prompt)
        return unless prompt.yes?('本当にこのレコードを削除しますか？ (y/N)')

        table = state[:selected_table]
        client.delete_record(table, pk_column, record[pk_column])
        refresh_records_safe(state, client, prompt)
        state[:selected_record_index] = 0
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to delete record: #{e.message}")
      end

      def execute_update(state, client, prompt, info)
        retries = 0
        loop do
          client.update_record(state[:selected_table], info[:pk_col], info[:pk_val], info[:col], info[:val])
          refresh_records_safe(state, client, prompt)
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= 5

          info[:val] = retry_update(e, prompt, info)
          break if info[:val].nil?
        end
      end

      def retry_update(error, prompt, info)
        msg = if error.respond_to?(:errno) && error.errno == 1062
                "主キーまたはユニーク制約違反です: #{error.message}"
              else
                "更新に失敗しました: #{error.message}"
              end
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val]) { |q| q.required true }
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
