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
        context = { data: data }
        with_retry(error_handler: ->(e) {
          context[:data] = handle_insert_error(e, prompt, columns, context[:data])
          context[:data].nil? || context[:data].empty?
        }) do
          RecordExecutor.execute_insert(state, client, prompt, context[:data])
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

        if RecordExecutor.confirm_and_delete(state, client, prompt, record, pk_column)
          state[:selected_record_index] = 0
        end
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
        with_retry(error_handler: ->(e) {
          handle_update_error(e, prompt, info)
          info[:val].nil?
        }) do
          RecordExecutor.execute_update(state, client, prompt, info)
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

      def with_retry(max_retries = 5, error_handler:)
        retries = 0
        loop do
          begin
            yield
            break
          rescue Mysql2::Error => e
            break if (retries += 1) >= max_retries
            break if error_handler.call(e)
          end
        end
      end
      private_class_method :with_retry
    end
  end
end
