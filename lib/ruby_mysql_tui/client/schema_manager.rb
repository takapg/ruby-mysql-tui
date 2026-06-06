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

    private

    def build_column_definitions(columns)
      columns.map do |col|
        name = col.is_a?(Hash) ? col[:name] : col
        type = col.is_a?(Hash) ? col[:type] : 'VARCHAR(255)'

        raise ArgumentError, "Invalid column type: #{type}" unless type.to_s.match?(/\A[a-zA-Z0-9\s(),]+\z/)

        "`#{name.gsub('`', '``')}` #{type}"
      end
    end
  end
end
