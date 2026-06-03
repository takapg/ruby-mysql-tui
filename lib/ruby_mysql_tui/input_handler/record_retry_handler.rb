# frozen_string_literal: true

require_relative 'record_executor'
require_relative 'record_prompt'

module RubyMysqlTui
  module InputHandler
    # RecordRetryHandler は レコード操作におけるリトライロジックとエラーハンドリングを提供します。
    module RecordRetryHandler
      module_function

      def execute_insert_with_retry(state, client, prompt, data, table_info)
        context = { data: data }
        with_retry(error_handler: lambda { |e|
          handle_insert_error_retry?(e, prompt, table_info[:columns], context, table_info[:structure] || [])
        }) do
          RecordExecutor.execute_insert(state, client, prompt, context[:data])
        end
      end

      def handle_insert_error_retry?(error, prompt, columns, context, structure = [])
        RubyMysqlTui.logger.error("Failed to insert record: #{error.message}")
        prompt.say("挿入に失敗しました: #{error.message}", color: :red)

        return true unless unique_constraint_violation?(error)

        new_data = RecordPrompt.prompt_for_record_data(columns, prompt, context[:data], structure)
        context[:data] = new_data
        new_data.nil? || new_data.empty?
      end

      def execute_update_with_retry(state, client, prompt, info)
        with_retry(error_handler: lambda { |e|
          handle_update_error_retry?(e, prompt, info)
        }) do
          RecordExecutor.execute_update(state, client, prompt, info)
        end
      end

      def handle_update_error_retry?(error, prompt, info)
        if unique_constraint_violation?(error)
          handle_unique_constraint_error_retry?(error, prompt, info)
        else
          handle_general_update_error_retry?(error, prompt, info)
        end
      end

      def unique_constraint_violation?(error)
        error.respond_to?(:errno) && error.errno == 1062
      end

      def handle_unique_constraint_error_retry?(error, prompt, info)
        msg = "入力された値は既に存在するため、保存できません（ユニーク制約違反）: #{error.message}"
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        info[:val] = prompt.ask("新しい値を入力してください (#{info[:col]}):", default: info[:val]) { |q| q.required true }
        info[:val].nil?
      end

      def handle_general_update_error_retry?(error, prompt, info)
        msg = "更新に失敗しました: #{error.message}"
        RubyMysqlTui.logger.error(msg)
        prompt.say(msg, color: :red)
        info[:val] = nil
        true
      end

      def with_retry(max_retries = 5, error_handler:)
        retries = 0
        loop do
          yield
          break
        rescue Mysql2::Error => e
          break if (retries += 1) >= max_retries
          break if error_handler.call(e)
        end
      end
    end
  end
end
