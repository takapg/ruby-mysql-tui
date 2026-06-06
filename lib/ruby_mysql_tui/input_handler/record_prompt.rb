# frozen_string_literal: true

require_relative 'record_validator'

module RubyMysqlTui
  module InputHandler
    # RecordPrompt は レコード操作におけるユーザー入力（プロンプト）を提供します。
    module RecordPrompt
      module_function

      def prompt_for_record_data(columns, prompt, default_data = {}, structure = [])
        columns.each_with_object({}) do |col, data|
          val = ask_for_value(col, prompt, default_data[col], structure, '値を入力してください')
          return nil if val.nil?

          data[col] = process_input_value(val, col, structure)
        end
      end

      def prompt_for_edit(record, prompt, pk_column = nil, structure = [])
        editable_columns = get_editable_columns(record, prompt, pk_column, structure)
        return nil if editable_columns.nil?

        column = prompt.select('編集するカラムを選択してください:', editable_columns)
        return nil if column.nil?

        value = ask_for_value(column, prompt, record[column], structure, '新しい値を入力してください')
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
          return '' if RecordValidator.string_type?(column, structure)
          return nil unless RecordValidator.required_column?(column, structure)
        end

        value
      end

      private_class_method def ask_for_value(col, prompt, default, structure, label)
        hint = build_hint(col, structure)
        prompt.ask("#{label} (#{col})#{hint}:", default: default) do |q|
          RecordValidator.apply_validations(q, col, structure)
        end
      end

      private_class_method def build_hint(col, structure)
        if RecordValidator.required_column?(col, structure)
          ''
        elsif RecordValidator.string_type?(col, structure)
          ' (Enter for empty string, "NULL" for NULL)'
        else
          ' (Enter for NULL)'
        end
      end

      private_class_method :handle_missing_pk, :handle_no_editable_cols, :process_input_value, :ask_for_value, :build_hint
    end
  end
end
