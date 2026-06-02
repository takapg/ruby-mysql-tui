# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordManagerHelpers は RecordManager のためのヘルパーメソッドを提供します。
    module RecordManagerHelpers
      module_function



    end

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
        data = RecordManagerHelpers.prompt_for_record_data(columns, prompt)
        return state if data.nil? || data.empty?

        execute_insert(state, client, prompt, columns, data)
        state
      end

      def handle_delete_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        confirm_and_delete(state, client, record, pk_column, prompt)
        state
      end

      def prompt_for_record_data(columns, prompt, default_data = {})
        columns.each_with_object({}) do |col, data|
          val = prompt.ask("値を入力してください (#{col}):", default: default_data[col])
          return nil if val.nil?

          data[col] = val
        end
      end

      def execute_insert(state, client, prompt, columns, data)
        retries = 0
        loop do
          client.insert_record(state[:selected_table], data)
          RecordManagerHelpers.refresh_records_safe(state, client, prompt)
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= 5

          data = RecordManagerHelpers.retry_insert(e, columns, prompt, data)
          break if data.nil? || data.empty?
        end
      end

      def retry_insert(error, columns, prompt, data)
        RubyMysqlTui.logger.error("Failed to insert record: #{error.message}")
        prompt.say("挿入に失敗しました: #{error.message}", color: :red)
        prompt_for_record_data(columns, prompt, data)
      end

      def can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def edit_and_update(state, client, record, pk_column, prompt)
        column, value = prompt_for_edit(record, prompt, pk_column)
        return if value.nil?

        execute_update(state, client, prompt, pk_col: pk_column, pk_val: record[pk_column], col: column, val: value)
      end

      def confirm_and_delete(state, client, record, pk_column, prompt)
        return unless prompt.yes?('本当にこのレコードを削除しますか？ (y/N)')

        table = state[:selected_table]
        client.delete_record(table, pk_column, record[pk_column])
        state[:records] = client.list_records(table, state[:records_offset] || 0)
        state[:selected_record_index] = 0
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to delete record: #{e.message}")
      end

      def prompt_for_edit(record, prompt, pk_column = nil)
        column = prompt.select('編集するカラムを選択してください:', record.keys)
        prompt_text = "新しい値を入力してください (#{column}):"
        prompt_text += ' [主キー]' if column == pk_column
        value = prompt.ask(prompt_text, default: record[column]) { |q| q.required true }
        [column, value]
      end

      def execute_update(state, client, prompt, info)
        retries = 0
        loop do
          client.update_record(state[:selected_table], info[:pk_col], info[:pk_val], info[:col], info[:val])
          RecordManagerHelpers.refresh_records_safe(state, client, prompt)
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= 5

          info[:val] = RecordManagerHelpers.retry_update(e, prompt, info)
          break if info[:val].nil?
        end
      end

      def retry_update(error, prompt, info)
        RubyMysqlTui.logger.error("Failed to update record: #{error.message}")

        error_msg = error.message
        display_msg = if error_msg.include?('Duplicate entry')
                        "主キーまたはユニーク制約違反（重複）です: #{error_msg}"
                      else
                        "更新に失敗しました: #{error_msg}"
                      end

        prompt.say(display_msg, color: :red)
        prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val])
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
