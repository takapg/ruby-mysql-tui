# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # TablePromptHelper は テーブル操作におけるユーザー入力（プロンプト）を提供します。
    module TablePromptHelper
      COLUMN_TYPES = ['INT', 'VARCHAR(255)", "TEXT", "DATETIME", "DATE", "OTHER (Custom Input)'].freeze

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

        type = prompt_type(prompt)
        null_constraint = prompt.yes?('NULLを許容しますか？') ? 'NULL' : 'NOT NULL'
        { name: name.strip, type: "#{type} #{null_constraint}" }
      end

      def prompt_type(prompt)
        type = prompt.select('データ型を選択してください:', COLUMN_TYPES)
        return type unless type == 'OTHER (Custom Input)'

        prompt_custom_type(prompt)
      end

      def prompt_custom_type(prompt)
        loop do
          custom = prompt.ask('データ型を入力してください (例: VARCHAR(64), DECIMAL(10,2)):')
          return custom if custom.to_s.match?(/\A[a-zA-Z0-9\s(),]+\z/)

          prompt.error('無効な文字が含まれています。英数字、スペース、カンマ、括弧のみ使用可能です。')
        end
      end
    end
  end
end
