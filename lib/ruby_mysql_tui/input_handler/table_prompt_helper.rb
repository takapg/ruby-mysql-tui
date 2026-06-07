# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TablePromptHelper は テーブル操作におけるユーザー入力（プロンプト）を提供します。
    module TablePromptHelper
      COLUMN_TYPES = ['INT', 'VARCHAR(255)', 'TEXT', 'DATETIME', 'DATE'].freeze

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
        null_allowed = prompt.yes?('NULLを許容しますか？')
        { name: name.strip, type: type, null: null_allowed }
      end

      def prompt_for_type_with_null(prompt, message)
        type = prompt.select(message, COLUMN_TYPES)
        null_allowed = prompt.yes?('NULLを許容しますか？')
        "#{type} #{null_allowed ? 'NULL' : 'NOT NULL'}"
      end

      def prompt_for_column_details(prompt)
        col_name = prompt.ask('追加するカラム名を入力してください:')
        return [nil, nil] if col_name.nil? || col_name.strip.empty?

        type_with_null = prompt_for_type_with_null(prompt, 'データ型を選択してください:')
        [col_name.strip, type_with_null]
      end
    end
  end
end
