# frozen_string_literal: true

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
        return state if data.empty?

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
        columns.to_h { |col| [col, prompt.ask("値を入力してください (#{col}):", default: default_data[col])] }
      end

      def execute_insert(state, client, prompt, columns, data)
        loop do
          client.insert_record(state[:selected_table], data)
          refresh_records_safe(state, client, prompt)
          break
        rescue Mysql2::Error => e
          RubyMysqlTui.logger.error("Failed to insert record: #{e.message}")
          prompt.say("挿入に失敗しました: #{e.message}", color: :red)
          break unless prompt.yes?('値を修正して再試行しますか？')

          data = prompt_for_record_data(columns, prompt, data)
        end
      end

      def can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def edit_and_update(state, client, record, pk_column, prompt)
        column, value = prompt_for_edit(record, prompt)
        return if value.nil?

        update_info = { pk_col: pk_column, pk_val: record[pk_column], col: column, val: value }
        execute_update(state, client, prompt, update_info)
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

      def prompt_for_edit(record, prompt)
        column = prompt.select('編集するカラムを選択してください:', record.keys)
        value = prompt.ask("新しい値を入力してください (#{column}):", default: record[column]) { |q| q.required true }
        [column, value]
      end

      def execute_update(state, client, prompt, info)
        loop do
          if update_record_safe(client, prompt, state[:selected_table], info)
            refresh_records_safe(state, client, prompt)
            break
          end

          break unless prompt.yes?('値を修正して再試行しますか？')

          info[:val] = prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val])
        end
      end

      def update_record_safe(client, prompt, table, info)
        client.update_record(table, info[:pk_col], info[:pk_val], info[:col], info[:val])
        true
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("Failed to update record: #{e.message}")
        prompt.say("更新に失敗しました: #{e.message}", color: :red)
        false
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
