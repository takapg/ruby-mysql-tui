# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
    # SqlExecutor は SQL の実行と結果の状態反映を提供します。
    module SqlExecutor
      module_function

      def apply_sql_result_state(state, results, sql)
        state.merge!(
          records: results,
          view_mode: :records,
          sql_mode: false,
          sql_history_index: nil,
          sql_result_mode: true,
          last_executed_sql: sql
        )
      end

      def apply_use_state(state, sql)
        state.merge!(
          view_mode: :tables,
          sql_mode: false,
          sql_history_index: nil,
          sql_result_mode: false,
          last_executed_sql: sql
        )
      end

      def apply_execution_state(state, sql, results, use_match)
        is_error = results.any? { |r| r.key?('Error') }

        if use_match && !is_error
          state[:selected_db] = use_match[1] || use_match[2]
          apply_use_state(state, sql)
        else
          apply_sql_result_state(state, results, sql)
        end
      end

      def query_mysql(sql, client)
        results = client.query(sql)
        return results if results

        affected = client.affected_rows
        last_id = client.last_id
        message = "Query OK, #{affected} rows affected"
        message += " (last id: #{last_id})" if last_id&.positive?
        [{ 'Result' => message }]
      rescue StandardError => e
        [{ 'Error' => e.message }]
      end

      public :apply_sql_result_state, :apply_use_state, :apply_execution_state, :query_mysql
    end
  end
end
