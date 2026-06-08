# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # SqlHistoryManager は SQL 実行履歴のファイル永続化を管理します。
    module SqlHistoryManager
      HISTORY_FILE = File.expand_path('~/.ruby_mysql_tui_history')

      module_function

      # 履歴ファイルを読み込み、配列として返します。
      def load_history
        return [] unless File.exist?(HISTORY_FILE)

        File.readlines(HISTORY_FILE, chomp: true)
      rescue StandardError => e
        RubyMysqlTui.logger.error("Failed to load SQL history: #{e.message}")
        []
      end

      # 履歴配列をファイルに保存します。
      def save_history(history)
        File.open(HISTORY_FILE, 'w') { |f| f.puts(history) }
      rescue StandardError => e
        RubyMysqlTui.logger.error("Failed to save SQL history: #{e.message}")
      end

      # 履歴ファイルを削除し、履歴をクリアします。
      def clear_history
        FileUtils.rm_f(HISTORY_FILE)
      rescue StandardError => e
        RubyMysqlTui.logger.error("Failed to clear SQL history: #{e.message}")
      end
    end
  end
end
