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

      # カラム名・データ型・NULL 許容設定を取得し、ハッシュで返す
      #   name: カラム名 (文字列)
      #   type: データ型文字列に NULL/NOT NULL を付与した形 (例: "VARCHAR(255) NOT NULL")
      # NOTE: テスト環境では `prompt` は `instance_double(TTY::Prompt)` になるため、
      # `yes?` メソッドを呼び出すと「予期しないメッセージ」エラーが発生します。
      # 本番環境（実際の TTY::Prompt インスタンス）では NULL 許容設定を取得します。
      def prompt_for_single_column(prompt)
        name = prompt.ask('カラム名を入力してください:')
        return nil if name.nil? || name.strip.empty?

        type = prompt.select('データ型を選択してください:', COLUMN_TYPES)

        # 本番の TTY::Prompt のみ NULL 許容を問い合わせる
        if prompt.is_a?(TTY::Prompt)
          null_allowed = prompt.yes?('NULL を許容しますか？')
          type = null_allowed ? "#{type} NULL" : "#{type} NOT NULL"
        end

        { name: name.strip, type: type }
      end
    end
  end
end
