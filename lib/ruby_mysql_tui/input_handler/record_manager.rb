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

        execute_insert_with_retry(state, client, prompt, data, columns)
        state
      end

      def execute_insert_with_retry(state, client, prompt, data, columns)
        retries = 0
        loop do
          RecordExecutor.execute_insert(state, client, prompt, data)
          break
        rescue Mysql2::Error => error
          break if (retries += 1) >= 5

          data = handle_insert_error(error, prompt, columns, data)
          break if data.nil? || data.empty?
        end
      end

      def handle_insert_error(error, prompt, columns, data)
        RubyMysqlTui.logger.error("Failed to insert record: #{error.message}")
        prompt.say("挿入に失敗しました: #{error.message}", color: :red)
        prompt_for_record_data(columns, prompt, data)
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

        info = { pk_col: pk_column, pk_val: record[pk_column], col: column, val: value }
        execute_update_with_retry(state, client, prompt, info)
      end

      def execute_update_with_retry(state, client, prompt, info)
        retries = 0
        loop do
          RecordExecutor.execute_update(state, client, prompt, info)
          break
        rescue Mysql2::Error => error
          break if (retries += 1) >= 5

          handle_update_error(error, prompt, info)
          break if info[:val].nil?
        end
      end

      def handle_update_error(error, prompt, info)
        msg = if error.respond_to?(:errno) && error.errno == 1062
                "主キーまたはユニーク制約違反です: #{error.message}"
              else
                "更新に失敗しました: #{error.message}"
              end
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        info[:val] = prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val]) { |q| q.required true }
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
