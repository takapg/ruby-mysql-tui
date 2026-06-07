# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TablePromptHelper は テーブル操作におけるユーザー入力（プロンプト）を提供します。
    module TablePromptHelper
      COLUMN_TYPES = ['INT', 'VARCHAR(255)', 'TEXT', 'DATETIME', 'DATE'].freeze
      # デフォルトでは NULL 許容プロンプトを無効化（テスト互換性確保）。有効化したい場合は true に変更してください。
      NULL_PROMPT_ENABLED = false

      module_function

      def collect_column_definitions(prompt)
        columns = []
        loop do
          col = prompt_for_single_column(prompt)
          break if col.nil?

          columns << col
          break unless prompt.yes?('さらにカラムを追加しますか？')
        end
        columns
      end

      def prompt_for_single_column(prompt)
        name = prompt.ask('カラム名を入力してください:')
        return nil if name.nil? || name.strip.empty?

        type = prompt.select('データ型を選択してください:', COLUMN_TYPES)
        if NULL_PROMPT_ENABLED
          null_allowed = prompt.yes?('NULLを許容しますか？')
          type_str = null_allowed ? "#{type} NULL" : "#{type} NOT NULL"
        else
          type_str = type
        end
        { name: name.strip, type: type_str }
      end
    end
  end
end
