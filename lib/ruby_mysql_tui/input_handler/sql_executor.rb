# frozen_string_literal: true

module RubyMysqlTui
  module InputHandler
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
    end
  end
end
