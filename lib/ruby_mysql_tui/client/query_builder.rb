# frozen_string_literal: true

module RubyMysqlTui
  class Client
    module QueryBuilder
      def build_list_records_sql(table_name, offset, limit, options)
        sql = "SELECT * FROM `#{table_name.gsub('`', '``')}`"
        sql = apply_filter(sql, table_name, options[:filter_query])
        sql = apply_sort(sql, options[:sort_column], options[:sort_direction])
        sql += " LIMIT #{limit} OFFSET #{offset}" if limit
        sql
      end

      def apply_filter(sql, table_name, query)
        return sql if query.nil? || query.empty?

        columns = list_columns(table_name)
        escaped = "%#{@connection.escape(query)}%"
        where = columns.map { |col| "`#{col.gsub('`', '``')}` LIKE '#{escaped}'" }.join(' OR ')
        "#{sql} WHERE (#{where})"
      end

      def apply_sort(sql, column, direction)
        return sql if column.nil?

        dir = %w[ASC DESC].include?(direction.to_s.upcase) ? direction.to_s.upcase : 'ASC'
        "#{sql} ORDER BY `#{column.gsub('`', '``')}` #{dir}"
      end
    end
  end
end
