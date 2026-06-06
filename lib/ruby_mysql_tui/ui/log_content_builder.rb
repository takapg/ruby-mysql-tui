# frozen_string_literal: true

module RubyMysqlTui
  module UI
    # LogContentBuilder は ログエリアに表示するコンテンツの構築ロジックを提供します。
    module LogContentBuilder
      module_function

      # ログに表示するテキストと、切り詰め(truncate)が必要かどうかを返します。
      # @return [Array(String, Boolean)] [text, should_truncate]
      def build(client, state)
        if state[:sql_mode]
          ["SQL MODE: #{state[:sql_input]} (Esc to cancel)", true]
        elsif state[:status_message]
          ["Status: #{state[:status_message]}", true]
        elsif state[:view_mode] == :record_detail
          build_detail_content(state)
        else
          sql = client.last_sql
          [sql ? "Last SQL: #{sql}" : 'No SQL executed', true]
        end
      end

      def build_detail_content(state)
        record = state[:records][state[:selected_record_index]]
        return ['No record selected', true] unless record

        column_name = record.keys[state[:selected_column_index]]
        column_value = record[column_name]
        text = "[Value of '#{column_name}']: #{column_value.nil? ? 'NULL' : column_value}"
        [text, false]
      end
    end
  end
end
