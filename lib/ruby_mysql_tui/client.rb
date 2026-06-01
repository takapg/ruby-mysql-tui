# frozen_string_literal: true

require 'mysql2'

module RubyMysqlTui
  # Client は MySQL 接続を管理し、クエリの実行を提供します。
  class Client
    attr_reader :connection, :config

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
      results = query("SHOW TABLES FROM #{database_name}")
      results.map { |row| row.values.first }
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
