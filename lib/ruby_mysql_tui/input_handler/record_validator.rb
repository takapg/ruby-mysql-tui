# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # RecordValidator は レコードのデータ型バリデーションを提供します。
    module RecordValidator
      module_function

      TYPE_VALIDATIONS = {
        /int/ => [/\A-?\d+\z/, '数値のみ入力してください'],
        /decimal|float|double/ => [/\A-?\d+(\.\d+)?\z/, '数値を入力してください'],
        /datetime|timestamp/ => [/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/, '日時形式 (YYYY-MM-DD HH:MM:SS) で入力してください'],
        /date/ => [/\A\d{4}-\d{2}-\d{2}\z/, '日付形式 (YYYY-MM-DD) で入力してください']
      }.freeze

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
