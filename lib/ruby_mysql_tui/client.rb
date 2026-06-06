# frozen_string_literal: true

require 'mysql2'
require_relative 'client/writer'

module RubyMysqlTui
  # Client は MySQL 接続を管理し、クエリの実行を提供します。
  class Client
    include Writer

    MAX_RECORDS_LIMIT = 10_000

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
      escaped_db_name = database_name.gsub('`', '``')
      results = query("SHOW TABLES FROM `#{escaped_db_name}`")
      results.map { |row| row.values.first }
    end

    # 指定したテーブルのレコード一覧を取得します。
    def list_records(table_name, offset = 0, limit: RubyMysqlTui::PAGE_SIZE, sort_column: nil, sort_direction: 'ASC')
      escaped_table_name = table_name.gsub('`', '``')
      sql = "SELECT * FROM `#{escaped_table_name}`"

      if sort_column
        direction = %w[ASC DESC].include?(sort_direction.to_s.upcase) ? sort_direction.to_s.upcase : 'ASC'
        sql += " ORDER BY `#{sort_column.gsub('`', '``')}` #{direction}"
      end

      sql += " LIMIT #{limit} OFFSET #{offset}" if limit

      query(sql)
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

    # データベースを作成します。
    def create_database(name)
      query("CREATE DATABASE `#{name.gsub('`', '``')}`")
    end

    # テーブルを作成します。
    def create_table(name, columns = [])
      escaped_name = name.gsub('`', '``')
      col_defs = ['id INT PRIMARY KEY AUTO_INCREMENT'] +
                 columns.map { |col| "`#{col.gsub('`', '``')}` VARCHAR(255)" }
      query("CREATE TABLE `#{escaped_name}` (#{col_defs.join(', ')})")
    end

    # データベースを削除します。
    def drop_database(name)
      query("DROP DATABASE `#{name.gsub('`', '``')}`")
    end

    # テーブルを削除します。
    def drop_table(name)
      query("DROP TABLE `#{name.gsub('`', '``')}`")
    end

    # テーブルの名前を変更します。
    def rename_table(old_name, new_name)
      query("RENAME TABLE `#{old_name.gsub('`', '``')}` TO `#{new_name.gsub('`', '``')}`")
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
