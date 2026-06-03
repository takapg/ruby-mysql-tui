# frozen_string_literal: true

require_relative 'record_executor'
require_relative 'record_prompt'

module RubyMysqlTui
  module InputHandler
    # RecordManager は レコードの削除などの操作を提供します。
    module RecordManager
      def self.handle_edit_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        edit_and_update(state, client, record, pk_column, prompt)
        state
      end

      def self.handle_create_record(state, client, prompt)
        return state unless can_manage_record?(state)

        columns = client.list_columns(state[:selected_table])
        data = RecordPrompt.prompt_for_record_data(columns, prompt)
        return state if data.nil? || data.empty?

        execute_insert_with_retry(state, client, prompt, data, columns)
        state
      end

      def self.execute_insert_with_retry(state, client, prompt, data, columns)
        context = { data: data }
        with_retry(error_handler: lambda { |e|
          context[:data] = handle_insert_error(e, prompt, columns, context[:data])
          context[:data].nil? || context[:data].empty?
        }) do
          RecordExecutor.execute_insert(state, client, prompt, context[:data])
        end
      end

      def self.handle_insert_error(error, prompt, columns, data)
        RubyMysqlTui.logger.error("Failed to insert record: #{error.message}")
        prompt.say("挿入に失敗しました: #{error.message}", color: :red)
        RecordPrompt.prompt_for_record_data(columns, prompt, data)
      end

      def self.handle_delete_record(state, client, prompt)
        return state unless can_manage_record?(state)

        record = state[:records][state[:selected_record_index]]
        pk_column = client.primary_key_for(state[:selected_table])
        return state unless record && pk_column

        state[:selected_record_index] = 0 if RecordExecutor.confirm_and_delete(state, client, prompt, record, pk_column)
        state
      end

      def self.can_manage_record?(state)
        state[:focus] == :right && state[:view_mode] == :records && state[:records]
      end

      def self.edit_and_update(state, client, record, pk_column, prompt)
        column, value = RecordPrompt.prompt_for_edit(record, prompt, pk_column)
        return if value.nil?

        info = { pk_col: pk_column, pk_val: record[pk_column], col: column, val: value }
        execute_update_with_retry(state, client, prompt, info)
      end

      def self.execute_update_with_retry(state, client, prompt, info)
        with_retry(error_handler: lambda { |e|
          handle_update_error(e, prompt, info)
        }) do
          RecordExecutor.execute_update(state, client, prompt, info)
        end
      end

      def self.handle_update_error(error, prompt, info)
        if unique_constraint_violation?(error)
          handle_unique_constraint_error(error, prompt, info)
        else
          handle_general_update_error(error, prompt, info)
        end
      end

      def self.unique_constraint_violation?(error)
        error.respond_to?(:errno) && error.errno == 1062
      end

      def self.handle_unique_constraint_error(error, prompt, info)
        msg = "入力された値は既に存在するため、保存できません（ユニーク制約違反）: #{error.message}"
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        info[:val] = prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val]) { |q| q.required true }
        false
      end

      def self.handle_general_update_error(error, prompt, info)
        msg = "更新に失敗しました: #{error.message}"
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        info[:val] = nil
        true
      end

      def self.with_retry(max_retries = 5, error_handler:)
        retries = 0
        loop do
          yield
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= max_retries
          break if error_handler.call(e)
        end
      end
      private_class_method :with_retry, :handle_update_error,
                           :unique_constraint_violation?,
                           :handle_unique_constraint_error,
                           :handle_general_update_error
    end
  end
end
