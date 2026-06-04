# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordPrompt は レコード操作におけるユーザー入力（プロンプト）を提供します。
    module RecordPrompt
      module_function

      TYPE_VALIDATIONS = {
        /int/ => [/\A-?\d+\z/, '数値のみ入力してください'],
        /decimal|float|double/ => [/\A-?\d+(\.\d+)?\z/, '数値を入力してください'],
        /datetime|timestamp/ => [/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/, '日時形式 (YYYY-MM-DD HH:MM:SS) で入力してください'],
        /date/ => [/\A\d{4}-\d{2}-\d{2}\z/, '日付形式 (YYYY-MM-DD) で入力してください']
      }.freeze

      def prompt_for_record_data(columns, prompt, default_data = {}, structure = [])
        columns.each_with_object({}) do |col, data|
          val = prompt.ask("値を入力してください (#{col}):", default: default_data[col]) do |question|
            apply_required_validation(question, col, structure)
            apply_type_validation(question, col, structure)
          end
          return nil if val.nil?

          data[col] = val
        end
      end

      def prompt_for_edit(record, prompt, pk_column = nil, structure = [])
        editable_columns = get_editable_columns(record, prompt, pk_column, structure)
        return nil if editable_columns.nil?

        column = prompt.select('編集するカラムを選択してください:', editable_columns)
        return nil if column.nil?

        value = prompt.ask("新しい値を入力してください (#{column}):", default: record[column]) do |question|
          apply_required_validation(question, column, structure)
          apply_type_validation(question, column, structure)
        end
        [column, value]
      end

      def get_editable_columns(record, prompt, pk_column, structure = [])
        pk_cols = structure.select { |c| c['Key'] == 'PRI' }.map { |c| c['Field'] }
        pk_cols = [pk_column] if pk_cols.empty? && pk_column

        if pk_cols.empty?
          warn_pk_missing(prompt)
          return nil
        end

        cols = record.keys - pk_cols
        if cols.empty?
          prompt.say('編集可能なカラムがありません', color: :yellow)
          return nil
        end

        cols
      end

      def warn_pk_missing(prompt)
        prompt.say('このテーブルには主キーが設定されていないため、レコードを特定して更新することができず、編集は不可能です', color: :yellow)
      end

      def warn_pk_not_editable(prompt)
        prompt.say('主キーは編集できません', color: :red)
      end

      def apply_required_validation(question, column, structure)
        return unless required_column?(column, structure)

        question.required true
        question.validate(/\S+/, '入力してください')
      end

      def required_column?(column_name, structure)
        col_info = structure.find { |c| c['Field'] == column_name }
        col_info&.[]('Null') == 'NO'
      end

      def apply_type_validation(question, column, structure)
        validation = type_validation_for(column, structure)
        return unless validation

        regex, message = validation
        # Nullableな場合は空文字を許容する
        regex = Regexp.union(regex, /\A\s*\z/) unless required_column?(column, structure)

        question.validate(regex, message)
      end

      def type_validation_for(column_name, structure)
        col_info = structure.find { |c| c['Field'] == column_name }
        type = col_info&.[]('Type')&.downcase
        return nil unless type

        TYPE_VALIDATIONS.find { |pattern, _| type.match?(pattern) }&.last
      end
    end
  end
end
