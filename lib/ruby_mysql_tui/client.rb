# frozen_string_literal: true

require 'mysql2'

module RubyMysqlTui
  # Client は MySQL 接続を管理し、クエリの実行を提供します。
  class Client
    attr_reader :connection, :config, :last_sql

    def initialize(config = {})
      @config = {
        host: config[:host] || ENV.fetch('MYSQL_HOST', 'localhost'),
        username: config[:username] || ENV.fetch('MYSQL_USER', 'root'),
        password: config[:password] || ENV.fetch('MYSQL_PASSWORD', ''),
        database: config[:database] || ENV.fetch('MYSQL_DATABASE', nil),
        connect_timeout: config[:connect_timeout] || 5
      }
      connect!
    end

    # SQL クエリを実行し、結果を返します。
    # 実行した SQL はロガーに出力されます。
    def query(sql)
      @last_sql = sql
      RubyMysqlTui.logger.info("Executing SQL: #{sql}")
      @connection.query(sql)
    rescue Mysql2::Error => e
      RubyMysqlTui.logger.error("MySQL Query Error: #{e.message}")
      raise e
    end

    # データベース一覧を取得します。
    def list_databases
      results = query('SHOW DATABASES')
      results.map { |row| row.values.first }
    end

    # データベースを選択します。
    def select_database(database_name)
      query("USE `#{database_name.gsub('`', '``')}`")
    end

    # 指定したデータベースのテーブル一覧を取得します。
    def list_tables(database_name)
      results = query("SHOW TABLES FROM `#{database_name}`")
      results.map { |row| row.values.first }
    end

    # 指定したテーブルのレコード一覧を取得します。
    def list_records(table_name, offset = 0)
      escaped_table_name = table_name.gsub('`', '``')
      query("SELECT * FROM `#{escaped_table_name}` LIMIT #{RubyMysqlTui::PAGE_SIZE} OFFSET #{offset}")
    end

    # テーブルのカラム一覧を取得します。
    def list_columns(table_name)
      escaped_table_name = table_name.gsub('`', '``')
      results = query("SHOW COLUMNS FROM `#{escaped_table_name}`")
      results.map { |row| row['Field'] }
    end

    # テーブルの主キー列名を取得します。
    def primary_key_for(table_name)
      escaped_table_name = table_name.gsub('`', '``')
      results = query("SHOW KEYS FROM `#{escaped_table_name}` WHERE Key_name = 'PRIMARY'")
      results.first ? results.first['Column_name'] : nil
    end

    # テーブルの構造（カラム定義）を取得します。
    def list_table_structure(table_name)
      escaped_table_name = table_name.gsub('`', '``')
      query("SHOW COLUMNS FROM `#{escaped_table_name}`")
    end

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

    # 接続を閉じます。
    def close
      @connection&.close
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

    def connect!
      @connection = Mysql2::Client.new(@config)
      RubyMysqlTui.logger.info("Successfully connected to MySQL at #{@config[:host]}")
    rescue Mysql2::Error => e
      RubyMysqlTui.logger.error("Failed to connect to MySQL: #{e.message}")
      raise e
    end
  end
end
