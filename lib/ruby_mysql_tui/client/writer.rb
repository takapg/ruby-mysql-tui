# frozen_string_literal: true

module RubyMysqlTui
  class Client
    # Writer は レコードの更新、挿入、削除などの書き込み操作を提供します。
    module Writer
      # レコードを更新します。
      def update_record(table_name, pk_column, pk_value, column_name, new_value)
        sql = "UPDATE `#{table_name.gsub('`', '``')}` " \
              "SET `#{column_name.gsub('`', '``')}` = ? " \
              "WHERE `#{pk_column.gsub('`', '``')}` = ?"
        log_prepared_sql(sql, new_value, pk_value)
        @connection.prepare(sql).execute(new_value, pk_value)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("MySQL Query Error: #{e.message}")
        raise e
      end

      # レコードを挿入します。
      def insert_record(table_name, data)
        sql = build_insert_sql(table_name, data)
        log_prepared_sql(sql, *data.values)
        @connection.prepare(sql).execute(*data.values)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("MySQL Query Error: #{e.message}")
        raise e
      end

      # レコードを削除します。
      def delete_record(table_name, pk_column, pk_value)
        sql = "DELETE FROM `#{table_name.gsub('`', '``')}` WHERE `#{pk_column.gsub('`', '``')}` = ?"
        log_prepared_sql(sql, pk_value)
        @connection.prepare(sql).execute(pk_value)
      rescue Mysql2::Error => e
        RubyMysqlTui.logger.error("MySQL Query Error: #{e.message}")
        raise e
      end

      private

      def build_insert_sql(table_name, data)
        cols = data.keys.map { |k| "`#{k.gsub('`', '``')}`" }.join(', ')
        placeholders = Array.new(data.size, '?').join(', ')
        "INSERT INTO `#{table_name.gsub('`', '``')}` (#{cols}) VALUES (#{placeholders})"
      end

      def log_prepared_sql(sql, *values)
        interpolated = sql.dup
        values.each do |val|
          quoted = val.is_a?(Numeric) ? val.to_s : "'#{val.to_s.gsub("'", "''")}'"
          interpolated.sub!('?', quoted)
        end
        @last_sql = interpolated
        RubyMysqlTui.logger.info("Executing SQL: #{@last_sql}")
      end
    end
  end
end
