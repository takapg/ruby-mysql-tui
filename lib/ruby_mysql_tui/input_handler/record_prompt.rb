# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordPrompt は レコード操作におけるユーザー入力（プロンプト）を提供します。
    module RecordPrompt
      module_function

      def prompt_for_record_data(columns, prompt, default_data = {})
        columns.each_with_object({}) do |col, data|
          val = prompt.ask("値を入力してください (#{col}):", default: default_data[col])
          return nil if val.nil?

          data[col] = val
        end
      end

      def prompt_for_edit(record, prompt, pk_column = nil)
        editable_columns = get_editable_columns(record, prompt, pk_column)
        return nil if editable_columns.nil?

        column = prompt.select('編集するカラムを選択してください:', editable_columns)
        return nil if column.nil?

        value = prompt.ask("新しい値を入力してください (#{column}):", default: record[column]) { |q| q.required true }
        [column, value]
      end

      def get_editable_columns(record, prompt, pk_column)
        if pk_column.nil?
          warn_pk_missing(prompt)
          return nil
        end

        cols = record.keys - [pk_column]
        if cols.empty?
          prompt.say('編集可能なカラムがありません', color: :yellow)
          return nil
        end

        cols
      end

      def warn_pk_missing(prompt)
        prompt.say('主キーが設定されていないため、編集できません', color: :yellow)
      end

      def warn_pk_not_editable(prompt)
        prompt.say('主キーは編集できません', color: :red)
      end
    end
  end
end
