# frozen_string_literal: true

require 'mysql2'
require_relative 'client/writer'
require_relative 'client/schema_manager'

module RubyMysqlTui
  # Client は MySQL 接続を管理し、クエリの実行を提供します。
  class Client
    include Writer
    include SchemaManager

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
    # 接続切れ (errno 2006, 2013) の場合は1回のみ再接続を試みます。
    def query(sql)
      @last_sql = sql
      RubyMysqlTui.logger.info("Executing SQL: #{sql}")
      with_reconnection_retry { @connection.query(sql) }
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
    def list_records(table_name, offset = 0, **options)
      limit = options[:limit] || RubyMysqlTui::PAGE_SIZE
      sql = build_list_records_sql(table_name, offset, limit, options)
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

    # 接続を閉じます。
    def close
      @connection&.close
    end

    private

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

    def with_reconnection_retry
      retried = false
      begin
        yield
      rescue Mysql2::Error => e
        return log_and_raise_error(e) if retried || !connection_lost?(e)

        handle_reconnection(e)
        retried = true
        retry
      end
    end

    def handle_reconnection(error)
      RubyMysqlTui.logger.warn("MySQL connection lost. Attempting to reconnect... (Error: #{error.errno})")
      connect!
    end

    def log_and_raise_error(error)
      RubyMysqlTui.logger.error("MySQL Query Error: #{error.message}")
      raise error
    end

    def connection_lost?(error)
      [2006, 2013].include?(error.errno)
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
