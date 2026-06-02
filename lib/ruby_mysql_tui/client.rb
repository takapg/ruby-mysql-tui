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

    # テーブルの主キー列名を取得します。
    def primary_key_for(table_name)
      escaped_table_name = table_name.gsub('`', '``')
      results = query("SHOW KEYS FROM `#{escaped_table_name}` WHERE Key_name = 'PRIMARY'")
      results.first ? results.first['Column_name'] : nil
    end

    # レコードを削除します。
    def delete_record(table_name, pk_column, pk_value)
      escaped_table_name = table_name.gsub('`', '``')
      escaped_pk_column = pk_column.gsub('`', '``')
      sql = "DELETE FROM `#{escaped_table_name}` WHERE `#{escaped_pk_column}` = ?"

      # ログ出力用にSQLを擬似的に構築
      val_for_log = pk_value.is_a?(Numeric) ? pk_value : "'#{pk_value.to_s.gsub("'", "''")}'"
      log_sql = sql.gsub('?', val_for_log.to_s)
      @last_sql = log_sql
      RubyMysqlTui.logger.info("Executing SQL: #{log_sql}")

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

    def connect!
      @connection = Mysql2::Client.new(@config)
      RubyMysqlTui.logger.info("Successfully connected to MySQL at #{@config[:host]}")
    rescue Mysql2::Error => e
      RubyMysqlTui.logger.error("Failed to connect to MySQL: #{e.message}")
      raise e
    end
  end
end
