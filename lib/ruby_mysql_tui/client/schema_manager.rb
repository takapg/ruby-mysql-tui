# frozen_string_literal: true

module RubyMysqlTui
  # SchemaManager は データベースやテーブルの作成、削除、変更などのスキーマ操作を提供します。
  module SchemaManager
    def create_database(name)
      query("CREATE DATABASE `#{name.gsub('`', '``')}`")
    end

    def create_table(name, columns = [])
      escaped_name = name.gsub('`', '``')
      col_defs = ['id INT PRIMARY KEY AUTO_INCREMENT'] + build_column_definitions(columns)
      query("CREATE TABLE `#{escaped_name}` (#{col_defs.join(', ')})")
    end

    def drop_database(name)
      query("DROP DATABASE `#{name.gsub('`', '``')}`")
    end

    def drop_table(name)
      query("DROP TABLE `#{name.gsub('`', '``')}`")
    end

    def truncate_table(name)
      query("TRUNCATE TABLE `#{name.gsub('`', '``')}`")
    end

    def rename_table(old_name, new_name)
      query("RENAME TABLE `#{old_name.gsub('`', '``')}` TO `#{new_name.gsub('`', '``')}`")
    end

    def drop_column(table_name, column_name)
      query("ALTER TABLE `#{table_name.gsub('`', '``')}` DROP COLUMN `#{column_name.gsub('`', '``')}`")
    end

    def rename_column(table_name, old_name, new_name)
      sql = "ALTER TABLE `#{table_name.gsub('`', '``')}` " \
            "RENAME COLUMN `#{old_name.gsub('`', '``')}` TO `#{new_name.gsub('`', '``')}`"
      query(sql)
    end

    def add_column(table_name, column_name, type)
      raise ArgumentError, "Invalid column type: #{type}" unless type.to_s.match?(/\A[a-zA-Z0-9\s(),]+\z/)

      escaped_table = table_name.gsub('`', '``')
      escaped_col = column_name.gsub('`', '``')
      query("ALTER TABLE `#{escaped_table}` ADD COLUMN `#{escaped_col}` #{type}")
    end

    def modify_column(table_name, column_name, type)
      raise ArgumentError, "Invalid column type: #{type}" unless type.to_s.match?(/\A[a-zA-Z0-9\s(),]+\z/)

      escaped_table = table_name.gsub('`', '``')
      escaped_col = column_name.gsub('`', '``')
      query("ALTER TABLE `#{escaped_table}` MODIFY COLUMN `#{escaped_col}` #{type}")
    end

    private

    def build_column_definitions(columns)
      columns.map do |col|
        name = col.is_a?(Hash) ? col[:name] : col
        type = col.is_a?(Hash) ? col[:type] : 'VARCHAR(255)'
        null_allowed = col.is_a?(Hash) ? col.fetch(:null, true) : true
        null_constraint = null_allowed ? 'NULL' : 'NOT NULL'

        raise ArgumentError, "Invalid column type: #{type}" unless type.to_s.match?(/\A[a-zA-Z0-9\s(),]+\z/)

        "`#{name.gsub('`', '``')}` #{type} #{null_constraint}"
      end
    end
  end
end
