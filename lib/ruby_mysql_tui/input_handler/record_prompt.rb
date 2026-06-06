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
          hint = if required_column?(col, structure)
                   ''
                 elsif string_type?(col, structure)
                   ' (Enter for empty string, "NULL" for NULL)'
                 else
                   ' (Enter for NULL)'
                 end
          val = prompt.ask("値を入力してください (#{col})#{hint}:", default: default_data[col]) do |question|
            apply_validations(question, col, structure)
          end
          return nil if val.nil?

          data[col] = process_input_value(val, col, structure)
        end
      end

      def prompt_for_edit(record, prompt, pk_column = nil, structure = [])
        editable_columns = get_editable_columns(record, prompt, pk_column, structure)
        return nil if editable_columns.nil?

        column = prompt.select('編集するカラムを選択してください:', editable_columns)
        return nil if column.nil?

        hint = if required_column?(column, structure)
                 ''
               elsif string_type?(column, structure)
                 ' (Enter for empty string, "NULL" for NULL)'
               else
                 ' (Enter for NULL)'
               end
        value = prompt.ask("新しい値を入力してください (#{column})#{hint}:", default: record[column]) do |question|
          apply_validations(question, column, structure)
        end
        return nil if value.nil?

        [column, process_input_value(value, column, structure)]
      end

      def get_editable_columns(record, prompt, pk_column, structure = [])
        pk_cols = identify_primary_keys(structure, pk_column)
        return handle_missing_pk(prompt) if pk_cols.empty?

        cols = record.keys - pk_cols
        return handle_no_editable_cols(prompt) if cols.empty?

        cols
      end

      def warn_pk_missing(prompt)
        prompt.say('このテーブルには主キーが設定されていないため、レコードを特定して更新することができず、編集は不可能です', color: :yellow)
      end

      def warn_pk_not_editable(prompt)
        prompt.say('主キーは編集できません', color: :red)
      end

      def identify_primary_keys(structure, pk_column)
        pk_cols = structure.select { |c| c['Key'] == 'PRI' }.map { |c| c['Field'] }
        pk_cols.empty? ? [pk_column].compact : pk_cols
      end

      def warn_no_editable_cols(prompt)
        prompt.say('編集可能なカラムがありません', color: :yellow)
      end

      def handle_missing_pk(prompt)
        warn_pk_missing(prompt)
        nil
      end

      def handle_no_editable_cols(prompt)
        warn_no_editable_cols(prompt)
        nil
      end

      def process_input_value(value, column, structure)
        return nil if value.to_s.upcase == 'NULL' || value.to_s == '\N'

        if value.to_s.strip.empty?
          return "" if string_type?(column, structure)
          return nil unless required_column?(column, structure)
        end

        value
      end
      private_class_method :handle_missing_pk, :handle_no_editable_cols, :process_input_value, :string_type?

      def apply_validations(question, column, structure)
        is_required = required_column?(column, structure)

        if is_required
          question.required true
          question.validate(/\S+/, '入力してください')
        end

        if (validation = type_validation_for(column, structure))
          regex, message = validation
          unless is_required
            # Nullableな場合は空文字、NULL、\N を許容する
            regex = Regexp.union(regex, /\A\s*\z/, /\ANULL\z/i, /\A\\N\z/)
          end
          question.validate(regex, message)
        end
      end

      def string_type?(column_name, structure)
        col_info = structure.find { |c| c['Field'] == column_name }
        type = col_info&.[]('Type')&.downcase
        return false unless type
        type.match?(/char|text/)
      end

      def required_column?(column_name, structure)
        col_info = structure.find { |c| c['Field'] == column_name }
        col_info&.[]('Null') == 'NO'
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
