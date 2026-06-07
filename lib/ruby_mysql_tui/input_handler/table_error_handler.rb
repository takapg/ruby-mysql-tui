# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TableErrorHandler は テーブル操作におけるエラーハンドリングを提供します。
    module TableErrorHandler
      module_function

      def handle_create_error(prompt, error)
        RubyMysqlTui.logger.error("Table Creation Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end

      def handle_truncate_error(prompt, error)
        RubyMysqlTui.logger.error("Table Truncate Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end

      def handle_add_column_error(prompt, error)
        RubyMysqlTui.logger.error("Table Add Column Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end

      def handle_modify_column_error(prompt, error)
        RubyMysqlTui.logger.error("Column Modify Error: #{error.message}")
        prompt.error("エラーが発生しました: #{error.message}")
      end
    end
  end
end
